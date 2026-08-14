// DictationMapperTests.swift — table-driven: transcript in → DictationResult out
// (§9.2 field-mapping contract, §9.4 parsing rules, §14).

import XCTest
@testable import TEELogCore

final class DictationMapperTests: XCTestCase {

    // MARK: - Fixtures

    private func finding(_ valve: Valve, _ lesion: LesionType, _ severity: SeverityGrade) -> ValveFindingRecord {
        ValveFindingRecord(valve: valve, lesion: lesion, severity: severity)
    }

    private func assertResolve(
        _ transcript: String,
        field: DictationField? = nil,
        procedure: ProcedureType? = nil,
        indications: Set<IndicationType> = [],
        views: Set<TEEView> = [],
        lvefQualitative: String? = nil,
        lvefPercent: Int? = nil,
        rvFunction: SeverityGrade? = nil,
        valveFindings: [ValveFindingRecord] = [],
        complications: Set<ComplicationType> = [],
        notes: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = DictationMapper.resolve(transcript, field: field)
        XCTAssertEqual(result.procedure, procedure, "procedure — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.indications, indications, "indications — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.views, views, "views — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.lvefQualitative, lvefQualitative, "lvefQualitative — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.lvefPercent, lvefPercent, "lvefPercent — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.rvFunction, rvFunction, "rvFunction — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.valveFindings, valveFindings, "valveFindings — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.complications, complications, "complications — transcript: \(transcript)", file: file, line: line)
        XCTAssertEqual(result.notes, notes, "notes — transcript: \(transcript)", file: file, line: line)
    }

    // MARK: - Procedure (§9.2 table row 1)

    func testProcedureMappings() {
        assertResolve("CABG", procedure: .cabg)
        assertResolve("coronary bypass", procedure: .cabg)
        assertResolve("AVR", procedure: .avr)
        assertResolve("aortic valve replacement", procedure: .avr)
        assertResolve("mitral repair", procedure: .mvr)
        assertResolve("mitral valve replacement", procedure: .mvr)
        assertResolve("TAVR", procedure: .tavr)
        assertResolve("MitraClip", procedure: .mitraclip)
        assertResolve("LVAD", procedure: .lvad)
        assertResolve("type A dissection", procedure: .typeADissection)
        assertResolve("heart transplant", procedure: .heartTransplant)
        assertResolve("watchman", procedure: .laao)
    }

    func testLongestMatchProcedureWinsOverShorterAlias() {
        // "coronary bypass" must parse as CABG, not leave "coronary" for the
        // ischemia indication.
        let result = DictationMapper.resolve("coronary bypass")
        XCTAssertEqual(result.procedure, .cabg)
        XCTAssertFalse(result.indications.contains(.ischemia))
    }

    // MARK: - Indication (§9.2 table row 2)

    func testIndicationMappings() {
        assertResolve("hypotension", indications: [.hemodynamic])
        assertResolve("shock", indications: [.hemodynamic])
        assertResolve("low blood pressure", indications: [.hemodynamic])
        assertResolve("murmur", indications: [.valvular])
        assertResolve("valve", indications: [.valvular])
        assertResolve("mass", indications: [.cardiacMass])
        assertResolve("clot", indications: [.cardiacMass])
        assertResolve("thrombus", indications: [.cardiacMass])
        assertResolve("fever", indications: [.endocarditis])
        assertResolve("vegetation", indications: [.endocarditis])
    }

    func testMultipleIndicationsParse() {
        assertResolve("fever and vegetation", indications: [.endocarditis])
        assertResolve("hypotension with a murmur", indications: [.hemodynamic, .valvular])
    }

    // MARK: - Views (§9.2 table row 3)

    func testViewMappings() {
        assertResolve("mid-esophageal four chamber", views: [.me4c])
        assertResolve("transgastric short axis", views: [.tgMidSax])
        assertResolve("deep transgastric", views: [.deepTgFiveChamber])
        assertResolve("bicaval", views: [.meBicaval])
        assertResolve("two chamber", views: [.me2c])
        assertResolve("aortic valve short axis", views: [.meAvSax])
        assertResolve("aortic valve long axis", views: [.meAvLax])
    }

    func testLongestMatchViewWins() {
        // "transgastric short axis" must win over the bare "short axis".
        assertResolve("transgastric short axis", views: [.tgMidSax])
        // "transgastric basal short axis" must win over "transgastric short axis".
        assertResolve("transgastric basal short axis", views: [.tgBasalSax])
        // "aortic arch long axis" vs generic "long axis".
        assertResolve("aortic arch long axis", views: [.ueAorticArchLax])
    }

    func testMultipleViewsParse() {
        assertResolve("bicaval and transgastric short axis", views: [.meBicaval, .tgMidSax])
    }

    // MARK: - LV EF (§9.2 table row 4)

    func testEFPercentMappings() {
        assertResolve("EF thirty percent", lvefPercent: 30)
        assertResolve("EF 30 percent", lvefPercent: 30)
        assertResolve("ejection fraction 45", lvefPercent: 45)
        assertResolve("EF 60%", lvefPercent: 60)
        assertResolve("EF is 50", lvefPercent: 50)
        assertResolve("squeeze 55", lvefPercent: 55)
    }

    func testEFPercentClamped() {
        assertResolve("EF 150 percent", lvefPercent: 100)
        assertResolve("EF 0 percent", lvefPercent: 0)
    }

    func testEFQualitativeMappings() {
        assertResolve("severely depressed", lvefQualitative: "severe")
        assertResolve("normal squeeze", lvefQualitative: "normal")
        assertResolve("normal", lvefQualitative: "normal")
        assertResolve("mildly reduced", lvefQualitative: "mild")
        assertResolve("moderately depressed", lvefQualitative: "moderate")
    }

    // MARK: - RV function (§9.2 table row 5)

    func testRVMappings() {
        assertResolve("RV normal", rvFunction: .none)
        assertResolve("mild RV dysfunction", rvFunction: .mild)
        assertResolve("RV failure", rvFunction: .severe)
        assertResolve("severe RV dysfunction", rvFunction: .severe)
        assertResolve("right ventricle dilated", rvFunction: .moderate)
    }

    func testRVSeverityDoesNotLeakToLVEF() {
        // "severe rv dysfunction" → RV severe, NOT lvefQualitative severe.
        let result = DictationMapper.resolve("severe RV dysfunction")
        XCTAssertEqual(result.rvFunction, .severe)
        XCTAssertNil(result.lvefQualitative)
    }

    // MARK: - Valve lesions (§9.2 table row 6)

    func testValveLesionMappings() {
        assertResolve("moderate aortic regurgitation", valveFindings: [finding(.aortic, .regurgitation, .moderate)])
        assertResolve("severe MR", valveFindings: [finding(.mitral, .regurgitation, .severe)])
        assertResolve("three plus mitral regurg", valveFindings: [finding(.mitral, .regurgitation, .moderate)])
        assertResolve("mild AS", valveFindings: [finding(.aortic, .stenosis, .mild)])
        assertResolve("2+ tricuspid regurgitation", valveFindings: [finding(.tricuspid, .regurgitation, .moderate)])
        assertResolve("4+ MR", valveFindings: [finding(.mitral, .regurgitation, .severe)])
        assertResolve("aortic insufficiency", valveFindings: [finding(.aortic, .regurgitation, .none)])
        assertResolve("mitral valve regurgitation", valveFindings: [finding(.mitral, .regurgitation, .none)])
        assertResolve("trace pulmonic regurgitation", valveFindings: [finding(.pulmonic, .regurgitation, .trace)])
    }

    func testMultipleValveLesionsParse() {
        assertResolve(
            "moderate aortic regurgitation and mild mitral stenosis",
            valveFindings: [
                finding(.aortic, .regurgitation, .moderate),
                finding(.mitral, .stenosis, .mild)
            ]
        )
    }

    func testValveAbbreviationInference() {
        // "MR" → mitral regurgitation; "AS" → aortic stenosis.
        let result = DictationMapper.resolve("severe MR")
        XCTAssertEqual(result.valveFindings, [finding(.mitral, .regurgitation, .severe)])
        let asResult = DictationMapper.resolve("mild AS")
        XCTAssertEqual(asResult.valveFindings, [finding(.aortic, .stenosis, .mild)])
    }

    func testValveLesionDoesNotFireOnProcedureWords() {
        // "aortic valve replacement" is a procedure, not a lesion.
        let result = DictationMapper.resolve("aortic valve replacement")
        XCTAssertEqual(result.procedure, .avr)
        XCTAssertTrue(result.valveFindings.isEmpty)
    }

    // MARK: - Complications (§9.2 table row 7)

    func testComplicationMappings() {
        assertResolve("dental trauma", complications: [.dentalTrauma])
        assertResolve("difficult probe insertion", complications: [.oropharyngeal])
        assertResolve("esophageal injury", complications: [.esophageal])
        assertResolve("no complications", complications: [.none])
        assertResolve("none", complications: [.none])
    }

    func testComplicationsDefaultToNone() {
        // Rule 7: absence of any match → .none (global parse).
        let result = DictationMapper.resolve("CABG")
        XCTAssertEqual(result.complications, [.none])
    }

    // MARK: - Notes fallback (§9.2 table row 8, §9.4 rule 8)

    func testUnconsumedTextGoesToNotes() {
        let result = DictationMapper.resolve("patient is stable on pressors")
        XCTAssertEqual(result.indications, [.hemodynamic]) // "pressors" consumed
        XCTAssertEqual(result.notes, "patient is stable on")
    }

    func testEverythingConsumedLeavesEmptyNotes() {
        let result = DictationMapper.resolve("CABG severe MR EF 30 percent")
        XCTAssertEqual(result.procedure, .cabg)
        XCTAssertEqual(result.valveFindings, [finding(.mitral, .regurgitation, .severe)])
        XCTAssertEqual(result.lvefPercent, 30)
        XCTAssertEqual(result.notes, "")
    }

    func testFillerWordsAreNotRulesButLandInNotes() {
        // Deterministic: "with" is not a vocabulary item → notes.
        let result = DictationMapper.resolve("CABG with severe MR")
        XCTAssertEqual(result.procedure, .cabg)
        XCTAssertEqual(result.notes, "with")
    }

    // MARK: - Global multi-field parse (§9.3 mode B)

    func testGlobalDictationParsesAllFields() {
        let result = DictationMapper.resolve(
            "TAVR for severe aortic stenosis, EF 35 percent, bicaval and deep transgastric"
        )
        XCTAssertEqual(result.procedure, .tavr)
        // The lesion phrase is consumed by the valve-lesion rule; the valvular
        // CATEGORY is still derived from the finding by AutoCategorizer.
        XCTAssertTrue(result.indications.isEmpty)
        XCTAssertEqual(result.valveFindings, [finding(.aortic, .stenosis, .severe)])
        XCTAssertEqual(result.lvefPercent, 35)
        XCTAssertEqual(result.views, [.meBicaval, .deepTgFiveChamber])
        XCTAssertEqual(result.complications, [.none])
    }

    func testBareLesionWordYieldsValvularIndication() {
        // Not consumed by the valve-lesion rule → indication alias fires.
        assertResolve("patient has stenosis", indications: [.valvular])
        assertResolve("regurgitation", indications: [.valvular])
    }

    // MARK: - Field-scoped resolve (§9.3 mode A)

    func testFieldScopedProcedure() {
        let result = DictationMapper.resolve("CABG with severe MR", field: .procedure)
        XCTAssertEqual(result.procedure, .cabg)
        XCTAssertTrue(result.valveFindings.isEmpty) // other fields untouched
        XCTAssertEqual(result.notes, "")
    }

    func testFieldScopedValveLesions() {
        let result = DictationMapper.resolve("severe MR", field: .valveLesions)
        XCTAssertNil(result.procedure)
        XCTAssertEqual(result.valveFindings, [finding(.mitral, .regurgitation, .severe)])
        XCTAssertEqual(result.notes, "")
    }

    func testFieldScopedViews() {
        let result = DictationMapper.resolve("bicaval", field: .views)
        XCTAssertEqual(result.views, [.meBicaval])
        XCTAssertNil(result.procedure)
    }

    func testFieldScopedIndication() {
        let result = DictationMapper.resolve("hypotension", field: .indication)
        XCTAssertEqual(result.indications, [.hemodynamic])
        XCTAssertNil(result.procedure)
    }

    func testFieldScopedNotesIsVerbatim() {
        let result = DictationMapper.resolve("  Any free text, with punctuation!  ", field: .notes)
        XCTAssertEqual(result.notes, "Any free text, with punctuation!")
    }

    func testFieldScopedComplicationsDefaultsToNone() {
        let result = DictationMapper.resolve("bicaval", field: .complications)
        XCTAssertEqual(result.complications, [.none])
    }

    // MARK: - Edge cases

    func testEmptyAndWhitespaceTranscripts() {
        assertResolve("")
        assertResolve("   ")
        XCTAssertEqual(DictationMapper.resolve("").notes, "")
    }

    func testPunctuationAndCaseInsensitivity() {
        let result = DictationMapper.resolve("MID-ESOPHAGEAL FOUR-CHAMBER, SEVERE MR!")
        XCTAssertEqual(result.views, [.me4c])
        XCTAssertEqual(result.valveFindings, [finding(.mitral, .regurgitation, .severe)])
    }

    func testTouchedFields() {
        var result = DictationResult()
        XCTAssertTrue(result.touchedFields.isEmpty)
        result.procedure = .cabg
        result.views = [.me4c]
        result.valveFindings = [finding(.mitral, .regurgitation, .moderate)]
        XCTAssertEqual(result.touchedFields, [.procedure, .views, .valveLesions])
    }
}
