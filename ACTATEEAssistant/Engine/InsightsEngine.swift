// InsightsEngine.swift — personal pattern insights over [CaseRecord] (F2).
//
// Pure, deterministic aggregations (no randomness; every output ordered by
// stable sort keys) so the Swift Charts cards and one-line takeaways are
// reproducible and unit-testable on Linux:
//
//   1. View coverage  — per procedure, which of the standard views the
//      fellow routinely skips (aggregate viewsObtained counts)
//   2. Severity distribution — per valve/lesion, distribution of logged
//      severities + an overcall heuristic (valve graded moderate/severe in
//      > 25% of that valve's logged cases)
//   3. RV undercall heuristic — LV moderate/severe with RV logged
//      normal/mild (or unlogged)
//   4. Indication–procedure mismatch — procedure logged without any
//      expected indication relationship
//   5. Monthly case mix — procedure-type counts per calendar month
//
// FEATURES.md F2 — no new data models, no network.

import Foundation

public enum InsightsEngine {

    // MARK: - 1. View coverage

    public struct ViewCoverageStat: Equatable, Sendable {
        public let procedure: ProcedureType
        public let view: TEEView
        public let obtainedCount: Int
        public let caseCount: Int

        public init(procedure: ProcedureType, view: TEEView, obtainedCount: Int, caseCount: Int) {
            self.procedure = procedure
            self.view = view
            self.obtainedCount = obtainedCount
            self.caseCount = caseCount
        }

        public var skipRate: Double {
            caseCount == 0 ? 0 : 1 - Double(obtainedCount) / Double(caseCount)
        }

        /// "70%" — one-line takeaway fragment (FEATURES.md example).
        public var skipPercentText: String { "\(Int((skipRate * 100).rounded()))%" }
    }

    // MARK: - 2. Severity distribution

    public struct SeverityDistribution: Equatable, Sendable {
        public let valve: Valve
        public let lesion: LesionType
        public let counts: [SeverityGrade: Int]

        public init(valve: Valve, lesion: LesionType, counts: [SeverityGrade: Int]) {
            self.valve = valve
            self.lesion = lesion
            self.counts = counts
        }

        public var caseCount: Int { counts.values.reduce(0, +) }

        /// Dominant grade (most logged; ties break to the more severe
        /// grade, then by rawValue order — deterministic).
        public var dominant: SeverityGrade? {
            counts.max { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.key.rank < rhs.key.rank
            }?.key
        }

        /// Overcall heuristic (FEATURES.md F2): any valve graded ≥ 3+ in
        /// > 25% of that valve's logged cases. On the 0/trace/1+/2+/4+
        /// scale (moderate = 2–3+, severe = 4+), "≥ 3+" is approximated by
        /// moderate-or-severe.
        public var overcallFlagged: Bool {
            guard caseCount > 0 else { return false }
            let highGradeCount = counts
                .filter { $0.key.rank >= SeverityGrade.moderate.rank }
                .values
                .reduce(0, +)
            return Double(highGradeCount) / Double(caseCount) > 0.25
        }
    }

    // MARK: - 3. RV undercall

    public struct RVUndercallCase: Equatable, Sendable {
        public let caseID: UUID
        public let examDate: Date
        public let procedure: ProcedureType
        public let lvefQualitative: String?   // "moderate"/"severe" — the LV side
        public let rvFunction: SeverityGrade? // nil or ≤ mild — the RV side

        public init(caseID: UUID, examDate: Date, procedure: ProcedureType, lvefQualitative: String?, rvFunction: SeverityGrade?) {
            self.caseID = caseID
            self.examDate = examDate
            self.procedure = procedure
            self.lvefQualitative = lvefQualitative
            self.rvFunction = rvFunction
        }
    }

    // MARK: - 4. Indication–procedure mismatch

    public struct MismatchCase: Equatable, Sendable {
        public let caseID: UUID
        public let examDate: Date
        public let procedure: ProcedureType
        public let indications: [IndicationType]
        public let expected: [IndicationType]

        public init(caseID: UUID, examDate: Date, procedure: ProcedureType, indications: [IndicationType], expected: [IndicationType]) {
            self.caseID = caseID
            self.examDate = examDate
            self.procedure = procedure
            self.indications = indications
            self.expected = expected
        }
    }

    // MARK: - 5. Monthly mix

    public struct MonthlyMixPoint: Equatable, Sendable {
        public let yearMonth: String      // "2026-07"
        public let procedure: ProcedureType
        public let count: Int

        public init(yearMonth: String, procedure: ProcedureType, count: Int) {
            self.yearMonth = yearMonth
            self.procedure = procedure
            self.count = count
        }
    }

    // MARK: - Report

    public struct InsightsReport: Equatable, Sendable {
        public let viewCoverage: [ViewCoverageStat]
        public let severityDistributions: [SeverityDistribution]
        public let rvUndercalls: [RVUndercallCase]
        public let mismatches: [MismatchCase]
        public let monthlyMix: [MonthlyMixPoint]

        // One-line takeaways for the chart cards (F2 acceptance).
        public let mostSkippedViewTakeaway: String?
        public let overcallTakeaways: [String]
        public let rvUndercallTakeaway: String?
        public let mismatchTakeaway: String?
        public let monthlyMixTakeaway: String?

        public init(
            viewCoverage: [ViewCoverageStat],
            severityDistributions: [SeverityDistribution],
            rvUndercalls: [RVUndercallCase],
            mismatches: [MismatchCase],
            monthlyMix: [MonthlyMixPoint],
            mostSkippedViewTakeaway: String?,
            overcallTakeaways: [String],
            rvUndercallTakeaway: String?,
            mismatchTakeaway: String?,
            monthlyMixTakeaway: String?
        ) {
            self.viewCoverage = viewCoverage
            self.severityDistributions = severityDistributions
            self.rvUndercalls = rvUndercalls
            self.mismatches = mismatches
            self.monthlyMix = monthlyMix
            self.mostSkippedViewTakeaway = mostSkippedViewTakeaway
            self.overcallTakeaways = overcallTakeaways
            self.rvUndercallTakeaway = rvUndercallTakeaway
            self.mismatchTakeaway = mismatchTakeaway
            self.monthlyMixTakeaway = monthlyMixTakeaway
        }
    }

    // MARK: - Entry point

    public static func report(from cases: [CaseRecord]) -> InsightsReport {
        InsightsReport(
            viewCoverage: viewCoverage(from: cases),
            severityDistributions: severityDistributions(from: cases),
            rvUndercalls: rvUndercalls(from: cases),
            mismatches: mismatches(from: cases),
            monthlyMix: monthlyMix(from: cases),
            mostSkippedViewTakeaway: mostSkippedViewTakeaway(from: cases),
            overcallTakeaways: overcallTakeaways(from: cases),
            rvUndercallTakeaway: rvUndercallTakeaway(from: cases),
            mismatchTakeaway: mismatchTakeaway(from: cases),
            monthlyMixTakeaway: monthlyMixTakeaway(from: cases)
        )
    }

    // MARK: - Aggregations

    /// Per (procedure, standard view): how often the view was logged.
    /// Only views skipped at least once are emitted (the "routinely skips"
    /// surface — fully-covered views are invisible by design).
    public static func viewCoverage(from cases: [CaseRecord]) -> [ViewCoverageStat] {
        var obtained: [String: Int] = [:]   // "proc|view" → obtained count
        var totals: [String: Int] = [:]     // "proc|view" → case count

        for record in cases {
            guard let procedure = ProcedureType(rawValue: record.procedure) else { continue }
            let views = Set(record.viewsObtained)
            for view in TEEView.allCases {
                let key = "\(procedure.rawValue)|\(view.rawValue)"
                totals[key, default: 0] += 1
                if views.contains(view.rawValue) { obtained[key, default: 0] += 1 }
            }
        }

        return totals
            .compactMap { key, caseCount -> ViewCoverageStat? in
                let parts = key.split(separator: "|")
                guard parts.count == 2,
                      let procedure = ProcedureType(rawValue: String(parts[0])),
                      let view = TEEView(rawValue: String(parts[1])),
                      caseCount > 0
                else { return nil }
                let obtainedCount = obtained[key, default: 0]
                guard obtainedCount < caseCount else { return nil } // skipped at least once
                return ViewCoverageStat(procedure: procedure, view: view, obtainedCount: obtainedCount, caseCount: caseCount)
            }
            .sorted {
                if $0.procedure.displayName != $1.procedure.displayName {
                    return $0.procedure.displayName < $1.procedure.displayName
                }
                return $0.view.displayName < $1.view.displayName
            }
    }

    /// Per (valve, lesion): severity histogram over logged findings.
    public static func severityDistributions(from cases: [CaseRecord]) -> [SeverityDistribution] {
        var buckets: [String: [SeverityGrade: Int]] = [:]

        for record in cases {
            for finding in record.valveFindings {
                let key = "\(finding.valve.rawValue)|\(finding.lesion.rawValue)"
                buckets[key, default: [:]][finding.severity, default: 0] += 1
            }
        }

        return buckets
            .compactMap { key, counts -> SeverityDistribution? in
                let parts = key.split(separator: "|")
                guard parts.count == 2,
                      let valve = Valve(rawValue: String(parts[0])),
                      let lesion = LesionType(rawValue: String(parts[1]))
                else { return nil }
                return SeverityDistribution(valve: valve, lesion: lesion, counts: counts)
            }
            .sorted {
                if $0.valve.displayName != $1.valve.displayName {
                    return $0.valve.displayName < $1.valve.displayName
                }
                return $0.lesion.displayName < $1.lesion.displayName
            }
    }

    /// RV undercall heuristic: LV moderate/severe while RV is logged
    /// normal/mild (or not logged). Sorted newest first.
    public static func rvUndercalls(from cases: [CaseRecord]) -> [RVUndercallCase] {
        cases
            .compactMap { record -> RVUndercallCase? in
                guard let procedure = ProcedureType(rawValue: record.procedure) else { return nil }
                guard let lvef = record.lvefQualitative,
                      ["moderate", "severe"].contains(lvef)
                else { return nil }
                let rv = record.rvFunction.flatMap(SeverityGrade.init(rawValue:))
                guard (rv?.rank ?? 0) <= SeverityGrade.mild.rank else { return nil } // normal-ish RV
                return RVUndercallCase(
                    caseID: record.id,
                    examDate: record.examDate,
                    procedure: procedure,
                    lvefQualitative: lvef,
                    rvFunction: rv
                )
            }
            .sorted { $0.examDate > $1.examDate }
    }

    /// Mismatch: procedure logged with none of its expected indication
    /// relationships (FEATURES.md F2 example: mitraclip with no valvular
    /// indication). Sorted newest first.
    public static func mismatches(from cases: [CaseRecord]) -> [MismatchCase] {
        cases
            .compactMap { record -> MismatchCase? in
                guard let procedure = ProcedureType(rawValue: record.procedure) else { return nil }
                let expected = expectedIndications(for: procedure)
                guard !expected.isEmpty else { return nil }
                let indications = record.indications.compactMap(IndicationType.init(rawValue:))
                guard Set(indications).isDisjoint(with: expected) else { return nil }
                return MismatchCase(
                    caseID: record.id,
                    examDate: record.examDate,
                    procedure: procedure,
                    indications: indications,
                    expected: expected
                )
            }
            .sorted { $0.examDate > $1.examDate }
    }

    /// Case counts per calendar month ("yyyy-MM") × procedure.
    public static func monthlyMix(from cases: [CaseRecord]) -> [MonthlyMixPoint] {
        let calendar = Calendar(identifier: .gregorian)
        var counts: [String: [String: Int]] = [:] // month → procedure → count

        for record in cases {
            guard let procedure = ProcedureType(rawValue: record.procedure) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: record.examDate)
            guard let year = comps.year, let month = comps.month else { continue }
            let key = String(format: "%04d-%02d", year, month)
            counts[key, default: [:]][procedure.rawValue, default: 0] += 1
        }

        return counts
            .flatMap { month, procedures in
                procedures.compactMap { raw, count -> MonthlyMixPoint? in
                    guard let procedure = ProcedureType(rawValue: raw) else { return nil }
                    return MonthlyMixPoint(yearMonth: month, procedure: procedure, count: count)
                }
            }
            .sorted {
                if $0.yearMonth != $1.yearMonth { return $0.yearMonth < $1.yearMonth }
                return $0.procedure.displayName < $1.procedure.displayName
            }
    }

    /// Expected indication relationships per procedure (drives #4).
    public static func expectedIndications(for procedure: ProcedureType) -> [IndicationType] {
        switch procedure {
        case .avr, .mvr, .tvr, .pvr:
            [.valvular]
        case .tavr:
            [.valvular, .aorticPathology, .structural]
        case .mitraclip, .tmvr, .tricuspidClip:
            [.valvular, .structural]
        case .laao:
            [.structural, .sourceOfEmbolus]
        case .cabg:
            [.ischemia, .hemodynamic]
        case .aorticRoot, .ascendingAorta, .typeADissection:
            [.aorticPathology]
        case .lvad, .rvad, .ecmo, .iabp:
            [.hemodynamic, .ventricularFunction]
        case .heartTransplant, .lungTransplant:
            [.ventricularFunction, .congenital, .hemodynamic]
        case .myectomy, .maze:
            [.structural, .ventricularFunction]
        case .other:
            []
        }
    }

    // MARK: - Takeaways (one-liners)

    /// "You skip TG RV inflow in 70% of AVR cases." — worst skip rate overall.
    public static func mostSkippedViewTakeaway(from cases: [CaseRecord]) -> String? {
        guard let stat = viewCoverage(from: cases).max(by: { lhs, rhs in
            if lhs.skipRate != rhs.skipRate { return lhs.skipRate < rhs.skipRate }
            if lhs.procedure != rhs.procedure { return lhs.procedure.displayName > rhs.procedure.displayName }
            return lhs.view.displayName > rhs.view.displayName
        }) else { return nil }
        return "You skip \(stat.view.displayName) in \(stat.skipPercentText) of \(stat.procedure.displayName) cases."
    }

    /// One line per overcall-flagged valve/lesion, e.g. "MR graded 2+/4+ in
    /// 60% of cases — possible overcall."
    public static func overcallTakeaways(from cases: [CaseRecord]) -> [String] {
        severityDistributions(from: cases)
            .filter(\.overcallFlagged)
            .sorted { $0.valve.displayName < $1.valve.displayName }
            .map { dist in
                let highGrade = dist.counts
                    .filter { $0.key.rank >= SeverityGrade.moderate.rank }
                    .values
                    .reduce(0, +)
                let pct = Int((Double(highGrade) / Double(max(dist.caseCount, 1)) * 100).rounded())
                return "\(dist.valve.shortCode) \(dist.lesion.displayName) graded 2+/4+ in \(pct)% of cases — possible overcall."
            }
    }

    public static func rvUndercallTakeaway(from cases: [CaseRecord]) -> String? {
        let flagged = rvUndercalls(from: cases)
        guard !flagged.isEmpty else { return nil }
        return "\(flagged.count) case\(flagged.count == 1 ? "" : "s") with normal/mild RV but moderate/severe LV — check for undercalled RV dysfunction."
    }

    public static func mismatchTakeaway(from cases: [CaseRecord]) -> String? {
        let flagged = mismatches(from: cases)
        guard !flagged.isEmpty else { return nil }
        let mostCommon = Dictionary(grouping: flagged, by: \.procedure)
            .max { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
                return lhs.key.displayName > rhs.key.displayName
            }?.key
        if let mostCommon {
            let expected = expectedIndications(for: mostCommon).map(\.displayName).joined(separator: " or ")
            return "\(flagged.count) mismatch\(flagged.count == 1 ? "" : "es"): \(mostCommon.displayName) without a \(expected) indication."
        }
        return nil
    }

    /// "Most active month: 2026-07 — AVR (12 cases)."
    public static func monthlyMixTakeaway(from cases: [CaseRecord]) -> String? {
        let points = monthlyMix(from: cases)
        guard !points.isEmpty else { return nil }
        let byMonth = Dictionary(grouping: points, by: \.yearMonth)
        let busiestMonth = byMonth.max { lhs, rhs in
            let l = lhs.value.reduce(0) { $0 + $1.count }
            let r = rhs.value.reduce(0) { $0 + $1.count }
            if l != r { return l < r }
            return lhs.key > rhs.key
        }
        guard let (month, monthPoints) = busiestMonth,
              let top = monthPoints.max(by: { $0.count < $1.count })?.procedure
        else { return nil }
        let topCount = monthPoints.first { $0.procedure == top }?.count ?? 0
        return "Most active month: \(month) — \(top.displayName) (\(topCount) case\(topCount == 1 ? "" : "s"))."
    }
}
