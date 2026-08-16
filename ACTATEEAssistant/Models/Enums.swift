// Enums.swift — all persisted raw-value enums.
//
// Pure Swift (Foundation only) so this compiles on Linux as part of
// ACTATEEAssistantCore. String raw values are STABLE — they are written into the
// SwiftData store and into exports; never rename a raw value, only add.
//
// IMPLEMENTATION.md §4.1

import Foundation

// MARK: - Procedure

public enum ProcedureType: String, CaseIterable, Codable, Hashable, Sendable {
    case cabg, avr, mvr, tvr, pvr, aorticRoot, ascendingAorta, typeADissection
    case heartTransplant, lungTransplant
    case lvad, rvad, ecmo, iabp
    case tavr, tmvr, mitraclip, tricuspidClip, laao
    case myectomy, maze, other

    public var displayName: String {
        switch self {
        case .cabg: "CABG"
        case .avr: "AVR"
        case .mvr: "MVR"
        case .tvr: "TVR"
        case .pvr: "PVR"
        case .aorticRoot: "Aortic root"
        case .ascendingAorta: "Ascending aorta"
        case .typeADissection: "Type A dissection"
        case .heartTransplant: "Heart transplant"
        case .lungTransplant: "Lung transplant"
        case .lvad: "LVAD"
        case .rvad: "RVAD"
        case .ecmo: "ECMO"
        case .iabp: "IABP"
        case .tavr: "TAVR"
        case .tmvr: "TMVR"
        case .mitraclip: "MitraClip"
        case .tricuspidClip: "Tricuspid clip"
        case .laao: "LAAO"
        case .myectomy: "Myectomy"
        case .maze: "Maze"
        case .other: "Other"
        }
    }
}

// MARK: - Indication

public enum IndicationType: String, CaseIterable, Codable, Hashable, Sendable {
    case hemodynamic, valvular, ventricularFunction, aorticPathology
    case cardiacMass, endocarditis, pericardial, congenital
    case structural, ischemia, sourceOfEmbolus, other

    public var displayName: String {
        switch self {
        case .hemodynamic: "Hemodynamic"
        case .valvular: "Valvular"
        case .ventricularFunction: "Ventricular function"
        case .aorticPathology: "Aortic pathology"
        case .cardiacMass: "Cardiac mass"
        case .endocarditis: "Endocarditis"
        case .pericardial: "Pericardial"
        case .congenital: "Congenital"
        case .structural: "Structural"
        case .ischemia: "Ischemia"
        case .sourceOfEmbolus: "Source of embolus"
        case .other: "Other"
        }
    }
}

// MARK: - TEE views (20 standard views)

public enum TEEView: String, CaseIterable, Codable, Hashable, Sendable {
    case me4c, me2c, meLax, meAvSax, meAvLax, meRvInflowOutflow
    case meBicaval, meAscAortaSax, meAscAortaLax, meDescAortaSax, meDescAortaLax
    case tgMidSax, tgBasalSax, tgTwoChamber, tgLax, tgRvInflow, deepTgFiveChamber
    case ueAorticArchSax, ueAorticArchLax

    public var displayName: String {
        switch self {
        case .me4c: "ME 4C"
        case .me2c: "ME 2C"
        case .meLax: "ME LAX"
        case .meAvSax: "ME AV SAX"
        case .meAvLax: "ME AV LAX"
        case .meRvInflowOutflow: "ME RV inflow-outflow"
        case .meBicaval: "ME bicaval"
        case .meAscAortaSax: "ME asc aorta SAX"
        case .meAscAortaLax: "ME asc aorta LAX"
        case .meDescAortaSax: "ME desc aorta SAX"
        case .meDescAortaLax: "ME desc aorta LAX"
        case .tgMidSax: "TG mid SAX"
        case .tgBasalSax: "TG basal SAX"
        case .tgTwoChamber: "TG 2-chamber"
        case .tgLax: "TG LAX"
        case .tgRvInflow: "TG RV inflow"
        case .deepTgFiveChamber: "Deep TG 5-chamber"
        case .ueAorticArchSax: "UE aortic arch SAX"
        case .ueAorticArchLax: "UE aortic arch LAX"
        }
    }
}

// MARK: - Case category (auto-assigned, drives requirement tracking)

public enum CaseCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case hemodynamic, ventricular, valvular, prosthetic, aorticPathology
    case structural, congenital, mass, pericardial, endocarditis, ischemia, mcs, transplant

    public var displayName: String {
        switch self {
        case .hemodynamic: "Hemodynamic"
        case .ventricular: "Ventricular"
        case .valvular: "Valvular"
        case .prosthetic: "Prosthetic valve"
        case .aorticPathology: "Aortic pathology"
        case .structural: "Structural"
        case .congenital: "Congenital"
        case .mass: "Mass"
        case .pericardial: "Pericardial"
        case .endocarditis: "Endocarditis"
        case .ischemia: "Ischemia"
        case .mcs: "MCS"
        case .transplant: "Transplant"
        }
    }
}

// MARK: - Findings

/// Maps directly to the echocardiographic 0 / trace / 1+ / 2+ / 3+ / 4+ scale
/// used in the UI stepper (§4 design note): none=0, trace=trace, mild=1+,
/// moderate=2–3+, severe=4+.
public enum SeverityGrade: String, CaseIterable, Codable, Hashable, Sendable {
    case none, trace, mild, moderate, severe

    /// Stepper / chip label ("0", "trace", "1+", "2+", "4+").
    public var plusNotation: String {
        switch self {
        case .none: "0"
        case .trace: "trace"
        case .mild: "1+"
        case .moderate: "2+"
        case .severe: "4+"
        }
    }

    /// Numeric echo scale used in exports ("AV:2+;MR:1+").
    public var exportNotation: String {
        switch self {
        case .none: "0"
        case .trace: "trace"
        case .mild: "1+"
        case .moderate: "2+"
        case .severe: "4+"
        }
    }

    /// Ordering rank for steppers/segmented controls.
    public var rank: Int {
        switch self {
        case .none: 0
        case .trace: 1
        case .mild: 2
        case .moderate: 3
        case .severe: 4
        }
    }
}

public enum LesionType: String, CaseIterable, Codable, Hashable, Sendable {
    case stenosis, regurgitation, mixed

    public var displayName: String {
        switch self {
        case .stenosis: "Stenosis"
        case .regurgitation: "Regurgitation"
        case .mixed: "Mixed"
        }
    }
}

public enum Valve: String, CaseIterable, Codable, Hashable, Sendable {
    case aortic, mitral, tricuspid, pulmonic

    public var displayName: String {
        switch self {
        case .aortic: "Aortic"
        case .mitral: "Mitral"
        case .tricuspid: "Tricuspid"
        case .pulmonic: "Pulmonic"
        }
    }

    /// Short code used in exports ("AV", "MV", "TV", "PV").
    public var shortCode: String {
        switch self {
        case .aortic: "AV"
        case .mitral: "MV"
        case .tricuspid: "TV"
        case .pulmonic: "PV"
        }
    }
}

// MARK: - Participation / quality / complications / tracks

public enum ParticipationLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case performed, supervised, interpreted

    public var displayName: String {
        switch self {
        case .performed: "Performed"
        case .supervised: "Supervised"
        case .interpreted: "Interpreted"
        }
    }
}

public enum ExamQuality: String, CaseIterable, Codable, Hashable, Sendable {
    case adequate, limited, uninterpretable

    public var displayName: String {
        switch self {
        case .adequate: "Adequate"
        case .limited: "Limited"
        case .uninterpretable: "Uninterpretable"
        }
    }
}

public enum ComplicationType: String, CaseIterable, Codable, Hashable, Sendable {
    case none, dentalTrauma, oropharyngeal, esophageal, other

    public var displayName: String {
        switch self {
        case .none: "None"
        case .dentalTrauma: "Dental trauma"
        case .oropharyngeal: "Oropharyngeal"
        case .esophageal: "Esophageal"
        case .other: "Other"
        }
    }
}

public enum TrackID: String, CaseIterable, Codable, Hashable, Sendable {
    case nbeAdvanced, nbeBasic, acgme

    public var displayName: String {
        switch self {
        case .nbeAdvanced: "NBE Advanced PTEeXAM"
        case .nbeBasic: "NBE Basic PTE"
        case .acgme: "ACGME"
        }
    }
}
