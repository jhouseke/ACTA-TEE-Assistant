// SpeechController.swift — SFSpeechRecognizer + AVAudioEngine wrapper (§9.1).
//
// APP TARGET ONLY (Speech + AVFoundation are Apple-only).
//
// Key privacy points (§9.1):
//   - requiresOnDeviceRecognition = true → audio never leaves the device
//     (falls back to server only when on-device is unsupported).
//   - SFSpeechRecognizer.requestAuthorization + AVAudioSession record
//     permission gated by the §10 Info.plist usage strings.

import Foundation
import Observation
import Speech
import AVFoundation

@MainActor
@Observable
final class SpeechController {

    enum SpeechError: LocalizedError, Equatable {
        case recognizerUnavailable
        case speechNotAuthorized
        case micDenied
        case onDeviceUnavailable
        case engine(String)

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                "Speech recognition isn't available on this device."
            case .speechNotAuthorized:
                "Dictation needs speech recognition permission. Enable it in Settings, or log manually."
            case .micDenied:
                "Dictation needs microphone access. Enable it in Settings, or log manually."
            case .onDeviceUnavailable:
                "On-device recognition isn't available for this locale on this device."
            case .engine(let message):
                "Speech engine error: \(message)"
            }
        }
    }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    var transcript: String = ""
    var isListening = false
    var lastError: SpeechError?

    /// True when the recognizer is available AND on-device recognition is
    /// configured (or the device doesn't support it, in which case the
    /// server fallback is used).
    var available: Bool { recognizer?.isAvailable ?? false }

    // MARK: - Authorization

    /// Requests speech + mic permission. Returns true when both are granted.
    func requestPermissionsIfNeeded() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            lastError = .speechNotAuthorized
            return false
        }
        let micGranted = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        if !micGranted { lastError = .micDenied }
        return micGranted
    }

    // MARK: - Capture

    /// Starts listening. Call `requestPermissionsIfNeeded()` first.
    /// Throws a `SpeechError` when the recognizer can't start.
    func start() throws {
        guard let recognizer, recognizer.isAvailable else {
            lastError = .recognizerUnavailable
            throw SpeechError.recognizerUnavailable
        }

        // Privacy: prefer on-device recognition (§9.1); only fall back to the
        // server when the hardware/locale can't do on-device.
        if recognizer.supportsOnDeviceRecognition {
            recognizer.requiresOnDeviceRecognition = true
        } else {
            lastError = .onDeviceUnavailable
            throw SpeechError.onDeviceUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = .engine("audio session: \(error.localizedDescription)")
            throw SpeechError.engine(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            lastError = .engine("no input format")
            throw SpeechError.engine("no input format")
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    // Not fatal — recognition just ended.
                    self.lastError = .engine(error.localizedDescription)
                    self.teardown()
                }
                if result?.isFinal == true {
                    self.teardown()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            transcript = ""
            lastError = nil
        } catch {
            lastError = .engine(error.localizedDescription)
            teardown()
            throw SpeechError.engine(error.localizedDescription)
        }
    }

    /// Ends recognition and tears down the engine.
    func stop() {
        request?.endAudio()
        teardown()
    }

    private func teardown() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request = nil
        task?.cancel()
        task = nil
        isListening = false
    }
}
