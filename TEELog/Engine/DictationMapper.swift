// DictationMapper.swift — transcript → typed field updates (§9).
//
// THE dictation module. Resolves a spoken transcript against the field
// vocabularies and alias dictionaries below and emits typed updates for the
// exact UI input fields: procedure, indication, views, LV EF, RV function,
// valve lesions, complications, notes.
//
// Parsing rules (§9.4), deterministic and unit-tested:
//   1. tokenize lowercased transcript; strip punctuation
//   2. valve lesions first (most specific, compound)
//   3. EF (numeric + qualitative)
//   4. RV
//   5. views (longest-match alias table)
//   6. procedures / indications (longest-match)
//   7. complications (absence of any match → .none)
//   8. fallback: unconsumed text → notes
//
// Pure Swift (Foundation only) — compiles on Linux as part of TEELogCore.

import Foundation

// MARK: - Field contract (§9.2)

/// Every dictatable input field. `resolve(_:field:)` scopes parsing to one
/// field (mode A — field-level mic); `resolve(_:)` with nil parses across
/// all fields at once (mode B — global dictation).
public enum DictationField: String, CaseIterable, Codable, Hashable, Sendable {
    case procedure
    case indication
    case views
    case lvef
    case rvFunction
    case valveLesions
    case complications
    case notes
}

/// Typed result of parsing a transcript (§9.3).
public struct DictationResult: Equatable, Sendable {
    public var procedure: ProcedureType?
    public var indications: Set<IndicationType>
    public var views: Set<TEEView>
    public var lvefQualitative: String?
    public var lvefPercent: Int?
    public var rvFunction: SeverityGrade?
    public var valveFindings: [ValveFindingRecord]
    public var complications: Set<ComplicationType>
    public var notes: String

    public init() {
        procedure = nil
        indications = []
        views = []
        lvefQualitative = nil
        lvefPercent = nil
        rvFunction = nil
        valveFindings = []
        complications = []
        notes = ""
    }

    /// Fields that carry at least one parsed value — drives the confirmation
    /// diff in the dictation sheet ("Added: … · Missed: —").
    public var touchedFields: [DictationField] {
        var out: [DictationField] = []
        if procedure != nil { out.append(.procedure) }
        if !indications.isEmpty { out.append(.indication) }
        if !views.isEmpty { out.append(.views) }
        if lvefQualitative != nil || lvefPercent != nil { out.append(.lvef) }
        if rvFunction != nil { out.append(.rvFunction) }
        if !valveFindings.isEmpty { out.append(.valveLesions) }
        if !complications.isEmpty { out.append(.complications) }
        if !notes.isEmpty { out.append(.notes) }
        return out
    }
}

// MARK: - Mapper

public enum DictationMapper {

    // MARK: Alias dictionaries — the SINGLE place to extend vocabulary (§9.4)

    /// Procedure aliases (§9.2: "CABG", "coronary bypass", "AVR",
    /// "mitral repair", "TAVR", "MitraClip", "LVAD", "type A dissection"…).
    public static let procedureAliases: [String: ProcedureType] = [
        "cabg": .cabg,
        "coronary bypass": .cabg,
        "coronary artery bypass": .cabg,
        "coronary artery bypass grafting": .cabg,
        "bypass surgery": .cabg,
        "avr": .avr,
        "aortic valve replacement": .avr,
        "mvr": .mvr,
        "mitral repair": .mvr,
        "mitral valve repair": .mvr,
        "mitral valve replacement": .mvr,
        "tvr": .tvr,
        "tricuspid valve repair": .tvr,
        "tricuspid valve replacement": .tvr,
        "pvr": .pvr,
        "pulmonic valve replacement": .pvr,
        "pulmonary valve replacement": .pvr,
        "aortic root": .aorticRoot,
        "root replacement": .aorticRoot,
        "bentall": .aorticRoot,
        "ascending aorta": .ascendingAorta,
        "ascending aortic": .ascendingAorta,
        "type a dissection": .typeADissection,
        "type a": .typeADissection,
        "heart transplant": .heartTransplant,
        "orthotopic heart transplant": .heartTransplant,
        "lung transplant": .lungTransplant,
        "double lung": .lungTransplant,
        "lvad": .lvad,
        "left ventricular assist device": .lvad,
        "ventricular assist device": .lvad,
        "rvad": .rvad,
        "right ventricular assist device": .rvad,
        "ecmo": .ecmo,
        "ecmo cannulation": .ecmo,
        "iabp": .iabp,
        "intra aortic balloon pump": .iabp,
        "balloon pump": .iabp,
        "tavr": .tavr,
        "transcatheter aortic valve": .tavr,
        "transcatheter aortic valve replacement": .tavr,
        "tmvr": .tmvr,
        "transcatheter mitral valve replacement": .tmvr,
        "mitraclip": .mitraclip,
        "mitra clip": .mitraclip,
        "mitral clip": .mitraclip,
        "tricuspid clip": .tricuspidClip,
        "tri clip": .tricuspidClip,
        "laao": .laao,
        "left atrial appendage occlusion": .laao,
        "watchman": .laao,
        "myectomy": .myectomy,
        "septal myectomy": .myectomy,
        "maze": .maze,
        "maze procedure": .maze,
        "afib ablation": .maze,
        "atrial fibrillation ablation": .maze,
        "other": .other
    ]

    /// Indication aliases (§9.2: "hypotension"/"shock"/"low blood pressure" →
    /// hemodynamic; "murmur"/"valve" → valvular; "mass"/"clot"/"thrombus" →
    /// cardiacMass; "fever"/"vegetation" → endocarditis …).
    public static let indicationAliases: [String: IndicationType] = [
        "hypotension": .hemodynamic,
        "shock": .hemodynamic,
        "low blood pressure": .hemodynamic,
        "hemodynamic": .hemodynamic,
        "hemodynamically unstable": .hemodynamic,
        "unstable": .hemodynamic,
        "pressors": .hemodynamic,
        "vasopressor": .hemodynamic,
        "low cardiac output": .hemodynamic,
        "murmur": .valvular,
        "valve": .valvular,
        "valvular": .valvular,
        "valve disease": .valvular,
        "valvular disease": .valvular,
        "stenosis": .valvular,
        "regurgitation": .valvular,
        "regurg": .valvular,
        "heart failure": .ventricularFunction,
        "cardiomyopathy": .ventricularFunction,
        "ventricular function": .ventricularFunction,
        "ventricular dysfunction": .ventricularFunction,
        "low ef": .ventricularFunction,
        "aortic dissection": .aorticPathology,
        "aortic aneurysm": .aorticPathology,
        "aortic pathology": .aorticPathology,
        "aortic disease": .aorticPathology,
        "mass": .cardiacMass,
        "clot": .cardiacMass,
        "thrombus": .cardiacMass,
        "cardiac mass": .cardiacMass,
        "tumor": .cardiacMass,
        "myxoma": .cardiacMass,
        "fever": .endocarditis,
        "vegetation": .endocarditis,
        "endocarditis": .endocarditis,
        "infective endocarditis": .endocarditis,
        "pericardial": .pericardial,
        "pericardial effusion": .pericardial,
        "pericarditis": .pericardial,
        "tamponade": .pericardial,
        "effusion": .pericardial,
        "congenital": .congenital,
        "congenital heart disease": .congenital,
        "asd": .congenital,
        "vsd": .congenital,
        "pfo": .congenital,
        "atrial septal defect": .congenital,
        "ventricular septal defect": .congenital,
        "patent foramen ovale": .congenital,
        "structural": .structural,
        "structural heart": .structural,
        "ischemia": .ischemia,
        "ischemic": .ischemia,
        "coronary": .ischemia,
        "myocardial infarction": .ischemia,
        "chest pain": .ischemia,
        "wall motion": .ischemia,
        "source of embolus": .sourceOfEmbolus,
        "embolic source": .sourceOfEmbolus,
        "embolus": .sourceOfEmbolus,
        "embolic": .sourceOfEmbolus,
        "stroke": .sourceOfEmbolus,
        "cva": .sourceOfEmbolus,
        "tia": .sourceOfEmbolus,
        "other": .other
    ]

    /// View aliases (§9.2: "mid-esophageal four chamber" → me4c;
    /// "transgastric short axis" → tgMidSax; "deep transgastric" →
    /// deepTgFiveChamber; "bicaval" → meBicaval). Longest match wins so
    /// "transgastric short axis" beats "short axis".
    public static let viewAliases: [String: TEEView] = [
        "mid esophageal four chamber": .me4c,
        "midesophageal four chamber": .me4c,
        "mid esophageal 4 chamber": .me4c,
        "me four chamber": .me4c,
        "four chamber": .me4c,
        "me 4c": .me4c,
        "mid esophageal two chamber": .me2c,
        "midesophageal two chamber": .me2c,
        "mid esophageal 2 chamber": .me2c,
        "me two chamber": .me2c,
        "two chamber": .me2c,
        "me 2c": .me2c,
        "mid esophageal long axis": .meLax,
        "midesophageal long axis": .meLax,
        "me long axis": .meLax,
        "long axis": .meLax,
        "me lax": .meLax,
        "three chamber": .meLax,
        "mid esophageal three chamber": .meLax,
        "mid esophageal aortic valve short axis": .meAvSax,
        "me aortic valve short axis": .meAvSax,
        "aortic valve short axis": .meAvSax,
        "me av sax": .meAvSax,
        "av short axis": .meAvSax,
        "mid esophageal aortic valve long axis": .meAvLax,
        "me aortic valve long axis": .meAvLax,
        "aortic valve long axis": .meAvLax,
        "me av lax": .meAvLax,
        "av long axis": .meAvLax,
        "me right ventricular inflow outflow": .meRvInflowOutflow,
        "me rv inflow outflow": .meRvInflowOutflow,
        "rv inflow outflow": .meRvInflowOutflow,
        "right ventricular inflow outflow": .meRvInflowOutflow,
        "bicaval": .meBicaval,
        "me bicaval": .meBicaval,
        "mid esophageal bicaval": .meBicaval,
        "bicaval view": .meBicaval,
        "me ascending aorta short axis": .meAscAortaSax,
        "ascending aorta short axis": .meAscAortaSax,
        "asc aorta sax": .meAscAortaSax,
        "ascending aortic short axis": .meAscAortaSax,
        "me ascending aorta long axis": .meAscAortaLax,
        "ascending aorta long axis": .meAscAortaLax,
        "asc aorta lax": .meAscAortaLax,
        "ascending aortic long axis": .meAscAortaLax,
        "me descending aorta short axis": .meDescAortaSax,
        "descending aorta short axis": .meDescAortaSax,
        "desc aorta sax": .meDescAortaSax,
        "me descending aorta long axis": .meDescAortaLax,
        "descending aorta long axis": .meDescAortaLax,
        "desc aorta lax": .meDescAortaLax,
        "transgastric short axis": .tgMidSax,
        "tg short axis": .tgMidSax,
        "tg mid sax": .tgMidSax,
        "transgastric mid short axis": .tgMidSax,
        "mid papillary": .tgMidSax,
        "transgastric basal short axis": .tgBasalSax,
        "tg basal sax": .tgBasalSax,
        "transgastric basal": .tgBasalSax,
        "tg basal": .tgBasalSax,
        "transgastric two chamber": .tgTwoChamber,
        "tg two chamber": .tgTwoChamber,
        "transgastric 2 chamber": .tgTwoChamber,
        "tg 2 chamber": .tgTwoChamber,
        "transgastric long axis": .tgLax,
        "tg long axis": .tgLax,
        "tg lax": .tgLax,
        "transgastric rv inflow": .tgRvInflow,
        "tg rv inflow": .tgRvInflow,
        "transgastric right ventricular inflow": .tgRvInflow,
        "deep transgastric": .deepTgFiveChamber,
        "deep transgastric five chamber": .deepTgFiveChamber,
        "deep tg": .deepTgFiveChamber,
        "deep tg five chamber": .deepTgFiveChamber,
        "deep transgastric 5 chamber": .deepTgFiveChamber,
        "upper esophageal aortic arch short axis": .ueAorticArchSax,
        "ue aortic arch sax": .ueAorticArchSax,
        "aortic arch short axis": .ueAorticArchSax,
        "aortic arch sax": .ueAorticArchSax,
        "upper esophageal aortic arch long axis": .ueAorticArchLax,
        "ue aortic arch lax": .ueAorticArchLax,
        "aortic arch long axis": .ueAorticArchLax,
        "aortic arch lax": .ueAorticArchLax
    ]

    /// Complication aliases (§9.2: "none", "dental trauma",
    /// "difficult probe insertion" → oropharyngeal …).
    public static let complicationAliases: [String: ComplicationType] = [
        "none": .none,
        "no complications": .none,
        "no complication": .none,
        "dental trauma": .dentalTrauma,
        "dental injury": .dentalTrauma,
        "tooth": .dentalTrauma,
        "difficult probe insertion": .oropharyngeal,
        "probe insertion": .oropharyngeal,
        "oropharyngeal": .oropharyngeal,
        "oropharyngeal injury": .oropharyngeal,
        "mucosal injury": .oropharyngeal,
        "lip laceration": .oropharyngeal,
        "esophageal": .esophageal,
        "esophageal injury": .esophageal,
        "esophageal perforation": .esophageal,
        "gastric injury": .esophageal,
        "other": .other
    ]

    /// LV EF qualitative aliases (§9.2: "severely depressed" → severe,
    /// "normal squeeze" → normal).
    public static let lvefQualitativeAliases: [String: String] = [
        "normal squeeze": "normal",
        "good squeeze": "normal",
        "squeeze": "normal",
        "normal": "normal",
        "preserved": "normal",
        "mildly depressed": "mild",
        "mild depression": "mild",
        "mildly reduced": "mild",
        "mildly impaired": "mild",
        "moderately depressed": "moderate",
        "moderate depression": "moderate",
        "moderately reduced": "moderate",
        "moderately impaired": "moderate",
        "depressed": "moderate",
        "reduced": "moderate",
        "severely depressed": "severe",
        "severe depression": "severe",
        "severely reduced": "severe",
        "severely impaired": "severe",
        "severe": "severe"
    ]

    // MARK: Parsing patterns (§9.4)

    /// Valve lesion, explicit valve: "(severity)? (valve) [valve] (lesion)".
    /// `valve` group also accepts abbreviations (av/mv/tv/pv/tr); lesion
    /// group accepts abbreviations (as/mr/tr/pr).
    private static let valvePatternExplicit =
        #"(trace|mild|moderate|severe|\d{1,2}\s*\+)?\s*(aortic|mitral|tricuspid|pulmonic|av|mv|tv|pv|tr)\s*(?:valve\s+)?(stenosis|regurgitation|regurg|insufficiency|as|mr|tr|pr)\b"#

    /// Valve lesion, abbreviation only ("mild AS", "severe MR") — the lesion
    /// abbreviation implies the valve (as→aortic, mr→mitral, tr→tricuspid,
    /// pr→pulmonic). Runs on text left over after the explicit pattern.
    private static let valvePatternAbbrev =
        #"(trace|mild|moderate|severe|\d{1,2}\s*\+)\s+(as|mr|tr|pr)\b"#

    /// EF numeric (§9.4 rule 3): "EF 30 percent" → 30; "ejection fraction
    /// 45%" → 45; "squeeze 55" → 55.
    private static let efNumberPattern =
        #"\b(?:ef|ejection fraction|squeeze)\b\D{0,6}(\d{1,3})\s*(?:percent|%)?"#

    /// RV, qualifier before ("mild RV dysfunction").
    private static let rvBeforePattern =
        #"\b(mild|moderate|severe|trace|dilated)\s+(rv|right ventricle|right ventricular)\s*(?:dysfunction|failure)?"#

    /// RV, qualifier after ("RV normal", "RV failure", "RV dilated").
    private static let rvAfterPattern =
        #"\b(rv|right ventricle|right ventricular)\s+(?:function\s+)?(normal|mild|moderate|severe|fails?|failure|dysfunction|dilated)\b"#

    /// Word numbers → digits, only before "plus"/"percent" (so "four
    /// chamber" stays a view phrase but "three plus" → "3+" and "thirty
    /// percent" → "30 percent").
    private static let wordNumbers: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
        "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
        "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
        "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
        "eighty": "80", "ninety": "90"
    ]

    // MARK: - Public API (§9.3)

    /// Resolve a transcript. With `field == nil` parses across ALL fields
    /// (global dictation, mode B); with a field scopes parsing to that field
    /// (mode A, field-level mic) — notes are then only populated for
    /// `field == .notes` (the whole transcript IS the note).
    public static func resolve(_ transcript: String, field: DictationField? = nil) -> DictationResult {
        var result = DictationResult()

        // Field-level notes: the entire transcript is the value (verbatim).
        if field == .notes {
            result.notes = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            return result
        }

        let text = normalize(transcript)
        guard !text.isEmpty else { return result }

        let nsText = text as NSString
        let blanked = NSMutableString(string: text)
        let isGlobal = (field == nil)
        let wants: (DictationField) -> Bool = { isGlobal || field == $0 }

        // Rule 2 — valve lesions first (most specific, compound).
        if wants(.valveLesions) {
            result.valveFindings = parseValveFindings(nsText: nsText, blanked: blanked)
        }

        // Rule 3 — EF numeric.
        if wants(.lvef), let percent = parseEFPercent(nsText: nsText, blanked: blanked) {
            result.lvefPercent = percent
        }

        // Rule 4 — RV (before qualitative EF so "severe rv dysfunction"
        // parses as RV, not LV EF).
        if wants(.rvFunction), let rv = parseRVFunction(nsText: nsText, blanked: blanked) {
            result.rvFunction = rv
        }

        // Rule 3 (cont.) — EF qualitative ("severely depressed", "normal").
        if wants(.lvef) {
            result.lvefQualitative = parseEFQualitative(blanked: blanked)
        }

        // Rule 5 — views (longest match).
        if wants(.views) {
            let matches = consumeAliases(viewAliases, nsText: nsText, blanked: blanked)
            for (_, value) in matches { result.views.insert(value) }
        }

        // Rule 6 — procedures, then indications (longest match).
        if wants(.procedure) {
            let matches = consumeAliases(procedureAliases, nsText: nsText, blanked: blanked)
            result.procedure = matches.min { $0.range.location < $1.range.location }?.value
        }
        if wants(.indication) {
            let matches = consumeAliases(indicationAliases, nsText: nsText, blanked: blanked)
            for (_, value) in matches { result.indications.insert(value) }
        }

        // Rule 7 — complications; absence of any match → .none.
        if wants(.complications) {
            let matches = consumeAliases(complicationAliases, nsText: nsText, blanked: blanked)
            for (_, value) in matches { result.complications.insert(value) }
            if result.complications.isEmpty {
                result.complications.insert(.none)
            } else if result.complications.contains(.none), result.complications.count > 1 {
                result.complications.remove(.none) // "none" + real complication
            }
        }

        // Rule 8 — fallback: anything not consumed goes to notes (global
        // mode only; field mode applies just that field's updates).
        if isGlobal {
            result.notes = leftoverText(blanked)
        }

        return result
    }

    // MARK: - Normalization

    /// Lowercase, strip punctuation (keep letters/digits/space/+/%),
    /// collapse whitespace, convert word numbers before plus/percent.
    private static func normalize(_ raw: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in raw.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " || scalar == "+" || scalar == "%" {
                scalars.append(scalar)
            } else {
                scalars.append(" ")
            }
        }
        let stripped = String(scalars)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return replaceWordNumbers(in: stripped)
    }

    /// Word numbers → digits before "percent" ("thirty percent" → "30 percent")
    /// and before "plus" ("three plus" → "3+", so the §9.4 N+ severity regex
    /// matches). "four chamber" is untouched ("chamber" is neither).
    private static func replaceWordNumbers(in text: String) -> String {
        // Pass 1: number word + "percent" → digit + " percent".
        let percentPattern = #"\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)\b(?=\s+percent\b)"#
        var result = replaceWords(matching: percentPattern, in: text) { word in
            wordNumbers[word] ?? word
        }
        // Pass 2: number word + "plus" → "N+".
        let plusPattern = #"\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)\b\s+plus\b"#
        result = replaceWords(matching: plusPattern, in: result) { match in
            let word = match.split(separator: " ").first.map(String.init) ?? match
            return (wordNumbers[word] ?? word) + "+"
        }
        return result
    }

    private static func replaceWords(matching pattern: String, in text: String, transform: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, range: full)
        guard !matches.isEmpty else { return text }
        var out = ""
        var cursor = 0
        for m in matches {
            out += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            let word = ns.substring(with: m.range)
            out += transform(word)
            cursor = m.range.location + m.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }

    // MARK: - Rule implementations

    private static func parseValveFindings(nsText: NSString, blanked: NSMutableString) -> [ValveFindingRecord] {
        var findings: [(location: Int, record: ValveFindingRecord)] = []

        // Explicit valve first…
        if let regex = try? NSRegularExpression(pattern: valvePatternExplicit, options: [.caseInsensitive]) {
            let matches = regex.matches(in: blanked as String, range: fullRange(blanked))
            for m in matches where m.numberOfRanges >= 4 {
                guard let record = makeFinding(
                    severityText: groupText(m, at: 1, nsText: nsText),
                    valveText: groupText(m, at: 2, nsText: nsText),
                    lesionText: groupText(m, at: 3, nsText: nsText)
                ) else { continue }
                findings.append((m.range.location, record))
                blank(m.range, in: blanked)
            }
        }
        // …then abbreviation-only ("mild AS", "severe MR").
        if let regex = try? NSRegularExpression(pattern: valvePatternAbbrev, options: [.caseInsensitive]) {
            let matches = regex.matches(in: blanked as String, range: fullRange(blanked))
            for m in matches where m.numberOfRanges >= 3 {
                guard let abbrev = groupText(m, at: 2, nsText: nsText) else { continue }
                guard let (valve, lesion) = valveLesion(forAbbreviation: abbrev) else { continue }
                let severity = severityGrade(fromText: groupText(m, at: 1, nsText: nsText)) ?? .none
                findings.append((m.range.location, ValveFindingRecord(valve: valve, lesion: lesion, severity: severity)))
                blank(m.range, in: blanked)
            }
        }

        return findings.sorted { $0.location < $1.location }.map(\.record)
    }

    private static func makeFinding(severityText: String?, valveText: String?, lesionText: String?) -> ValveFindingRecord? {
        guard let valveText, let lesionText else { return nil }
        guard let valve = valve(fromText: valveText) else { return nil }
        guard let lesion = lesion(fromText: lesionText) else { return nil }
        let severity = severityGrade(fromText: severityText) ?? .none
        return ValveFindingRecord(valve: valve, lesion: lesion, severity: severity)
    }

    private static func valve(fromText text: String) -> Valve? {
        switch text {
        case "aortic", "av": .aortic
        case "mitral", "mv": .mitral
        case "tricuspid", "tv", "tr": .tricuspid
        case "pulmonic", "pv": .pulmonic
        default: nil
        }
    }

    private static func lesion(fromText text: String) -> LesionType? {
        switch text {
        case "stenosis", "as": .stenosis
        case "regurgitation", "regurg", "insufficiency", "mr", "tr", "pr": .regurgitation
        default: nil
        }
    }

    /// Abbreviation-only lesion ("as"/"mr"/"tr"/"pr") → implied valve.
    private static func valveLesion(forAbbreviation abbrev: String) -> (Valve, LesionType)? {
        switch abbrev {
        case "as": (.aortic, .stenosis)
        case "mr": (.mitral, .regurgitation)
        case "tr": (.tricuspid, .regurgitation)
        case "pr": (.pulmonic, .regurgitation)
        default: nil
        }
    }

    /// Severity word → grade; "N+" → grade (§4 note: 1+=mild, 2+=moderate,
    /// 3+=moderate, 4+=severe; 0→none; ≥5 clamped to severe).
    private static func severityGrade(fromText text: String?) -> SeverityGrade? {
        guard let text else { return nil }
        switch text {
        case "trace": return .trace
        case "mild": return .mild
        case "moderate": return .moderate
        case "severe": return .severe
        default:
            let digits = text.filter(\.isNumber)
            guard let n = Int(digits) else { return nil }
            switch n {
            case 0: return SeverityGrade.none
            case 1: return SeverityGrade.mild
            case 2, 3: return SeverityGrade.moderate
            default: return SeverityGrade.severe
            }
        }
    }

    private static func parseEFPercent(nsText: NSString, blanked: NSMutableString) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: efNumberPattern, options: [.caseInsensitive]) else { return nil }
        let matches = regex.matches(in: blanked as String, range: fullRange(blanked))
        var firstValue: Int?
        for m in matches {
            if firstValue == nil, m.numberOfRanges >= 2,
               let value = Int(nsText.substring(with: m.range(at: 1))) {
                firstValue = min(max(value, 0), 100)
            }
            blank(m.range, in: blanked)
        }
        return firstValue
    }

    private static func parseEFQualitative(blanked: NSMutableString) -> String? {
        let matches = consumeAliases(lvefQualitativeAliases, nsText: blanked as NSString, blanked: blanked)
        return matches.min { $0.range.location < $1.range.location }?.value
    }

    private static func parseRVFunction(nsText: NSString, blanked: NSMutableString) -> SeverityGrade? {
        var found: (location: Int, grade: SeverityGrade)? = nil

        if let regex = try? NSRegularExpression(pattern: rvBeforePattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: blanked as String, range: fullRange(blanked))
            for m in matches where m.numberOfRanges >= 2 {
                let qualifier = nsText.substring(with: m.range(at: 1))
                let grade = rvGrade(fromQualifier: qualifier) ?? .moderate
                if found == nil || m.range.location < found!.location {
                    found = (m.range.location, grade)
                }
                blank(m.range, in: blanked)
            }
        }
        if let regex = try? NSRegularExpression(pattern: rvAfterPattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: blanked as String, range: fullRange(blanked))
            for m in matches where m.numberOfRanges >= 3 {
                let qualifier = nsText.substring(with: m.range(at: 2))
                let grade = rvGrade(fromQualifier: qualifier) ?? .moderate
                if found == nil || m.range.location < found!.location {
                    found = (m.range.location, grade)
                }
                blank(m.range, in: blanked)
            }
        }
        return found?.grade
    }

    /// RV qualifier → dysfunction grade. "normal" → .none (no dysfunction);
    /// "failure"/"fails" → .severe; "dilated"/"dysfunction" (bare) →
    /// .moderate.
    private static func rvGrade(fromQualifier qualifier: String) -> SeverityGrade? {
        switch qualifier {
        case "normal": SeverityGrade.none
        case "mild": SeverityGrade.mild
        case "moderate": SeverityGrade.moderate
        case "severe": SeverityGrade.severe
        case "fail", "fails", "failure": SeverityGrade.severe
        case "dilated", "dysfunction": SeverityGrade.moderate
        default: nil
        }
    }

    // MARK: - Alias longest-match

    /// Consume aliases longest-first from `blanked` (previously consumed
    /// regions are spaces and can't re-match). Returns (range, value) pairs;
    /// ranges index into the shared normalized string.
    private static func consumeAliases<T>(
        _ aliases: [String: T],
        nsText: NSString,
        blanked: NSMutableString
    ) -> [(range: NSRange, value: T)] {
        var out: [(NSRange, T)] = []
        let sorted = aliases.keys.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a < b
        }
        for alias in sorted {
            guard let value = aliases[alias] else { continue }
            var search = NSRange(location: 0, length: blanked.length)
            while true {
                let r = blanked.range(of: alias, options: [.caseInsensitive], range: search)
                if r.location == NSNotFound { break }
                out.append((r, value))
                blank(r, in: blanked)
                let next = r.location + r.length
                if next >= blanked.length { break }
                search = NSRange(location: next, length: blanked.length - next)
            }
        }
        return out
    }

    // MARK: - Helpers

    private static func fullRange(_ s: NSMutableString) -> NSRange {
        NSRange(location: 0, length: s.length)
    }

    private static func groupText(_ match: NSTextCheckingResult, at index: Int, nsText: NSString) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let r = match.range(at: index)
        guard r.location != NSNotFound else { return nil }
        return nsText.substring(with: r)
    }

    private static func blank(_ range: NSRange, in blanked: NSMutableString) {
        blanked.replaceCharacters(in: range, with: String(repeating: " ", count: range.length))
    }

    private static func leftoverText(_ blanked: NSMutableString) -> String {
        (blanked as String)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
