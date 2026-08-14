// AutoCategorizerTests.swift — table-driven, deterministic (§6, §14).

import XCTest
@testable import TEELogCore

final class AutoCategorizerTests: XCTestCase {

    // MARK: - Fixtures

    private func finding(_ valve: Valve, _ lesion: LesionType, _ severity: SeverityGrade) -> ValveFindingRecord {
        ValveFindingRecord(valve: valve, lesion: lesion, severity: severity)
    }

    private func assertCategories(
        _ procedure: ProcedureType,
        _ indications: [IndicationType],
        _ valveFindings: [ValveFindingRecord] = [],
        lvef: String? = nil,
        rv: String? = nil,
        expected: Set<CaseCategory>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = AutoCategorizer.categorize(
            procedure: procedure,
            indications: indications,
            valveFindings: valveFindings,
            lvef: lvef,
            rv: rv
        )
        XCTAssertEqual(actual, expected, "procedure=\(procedure.rawValue) indications=\(indications.map(\.rawValue))", file: file, line: line)
    }

    // MARK: - Procedure-driven categories

    func testValvularOnlyProcedures() {
        // §6 sets — exactly as specified: these are valvular but NOT structural.
        for p in [ProcedureType.avr, .mvr, .tvr, .pvr, .myectomy] {
            assertCategories(p, [], expected: [.valvular])
        }
    }

    func testStructuralOnlyProcedures() {
        // §6 sets: TAVR and LAAO are structural but NOT in valvularProcedures.
        for p in [ProcedureType.tavr, .laao] {
            assertCategories(p, [], expected: [.structural])
        }
    }

    func testStructuralAndValvularProcedures() {
        // §6 sets: clip/TMVR procedures appear in BOTH sets.
        for p in [ProcedureType.mitraclip, .tmvr, .tricuspidClip] {
            assertCategories(p, [], expected: [.structural, .valvular])
        }
    }

    func testMCSProcedures() {
        for p in [ProcedureType.lvad, .rvad, .ecmo, .iabp] {
            assertCategories(p, [], expected: [.mcs])
        }
    }

    func testAorticProcedures() {
        for p in [ProcedureType.aorticRoot, .ascendingAorta, .typeADissection] {
            assertCategories(p, [], expected: [.aorticPathology])
        }
    }

    func testTransplantProcedures() {
        for p in [ProcedureType.heartTransplant, .lungTransplant] {
            assertCategories(p, [], expected: [.transplant])
        }
    }

    func testPlainCABGWithNoIndicationsIsUncategorized() {
        assertCategories(.cabg, [], expected: [])
    }

    func testOtherProcedureWithNoIndicationsIsUncategorized() {
        assertCategories(.other, [], expected: [])
    }

    // MARK: - Indication-driven categories

    func testIndicationsMapToCategories() {
        assertCategories(.cabg, [.hemodynamic], expected: [.hemodynamic])
        assertCategories(.cabg, [.ventricularFunction], expected: [.ventricular])
        assertCategories(.cabg, [.valvular], expected: [.valvular])
        assertCategories(.cabg, [.aorticPathology], expected: [.aorticPathology])
        assertCategories(.cabg, [.structural], expected: [.structural])
        assertCategories(.cabg, [.cardiacMass], expected: [.mass])
        assertCategories(.cabg, [.endocarditis], expected: [.endocarditis])
        assertCategories(.cabg, [.pericardial], expected: [.pericardial])
        assertCategories(.cabg, [.congenital], expected: [.congenital])
        assertCategories(.cabg, [.ischemia], expected: [.ischemia])
        assertCategories(.cabg, [.sourceOfEmbolus], expected: [])
        assertCategories(.cabg, [.other], expected: [])
    }

    func testMultipleIndicationsAccumulate() {
        assertCategories(.cabg, [.hemodynamic, .ischemia], expected: [.hemodynamic, .ischemia])
    }

    // MARK: - Finding-driven categories

    func testValveFindingsTriggerValvular() {
        assertCategories(.cabg, [], valveFindings: [finding(.mitral, .regurgitation, .severe)], expected: [.valvular])
        assertCategories(.cabg, [], valveFindings: [finding(.aortic, .stenosis, .mild)], expected: [.valvular])
    }

    func testValveFindingsSeverityDoesNotMatterForCategory() {
        // Even a trace finding counts toward the valvular category.
        assertCategories(.cabg, [], valveFindings: [finding(.tricuspid, .regurgitation, .trace)], expected: [.valvular])
    }

    // MARK: - Ventricular function

    func testModerateOrSevereLVEFAddsVentricular() {
        assertCategories(.cabg, [], lvef: "moderate", expected: [.ventricular])
        assertCategories(.cabg, [], lvef: "severe", expected: [.ventricular])
    }

    func testNormalOrMildLVEFDoesNotAddVentricular() {
        assertCategories(.cabg, [], lvef: "normal", expected: [])
        assertCategories(.cabg, [], lvef: "mild", expected: [])
    }

    func testModerateOrSevereRVAddsVentricular() {
        assertCategories(.cabg, [], rv: "moderate", expected: [.ventricular])
        assertCategories(.cabg, [], rv: "severe", expected: [.ventricular])
    }

    func testNormalOrMildRVDoesNotAddVentricular() {
        assertCategories(.cabg, [], rv: "none", expected: [])
        assertCategories(.cabg, [], rv: "mild", expected: [])
    }

    // MARK: - Combined

    func testCombinedCaseAccumulatesEveryRule() {
        assertCategories(
            .avr,
            [.hemodynamic, .endocarditis],
            valveFindings: [finding(.aortic, .regurgitation, .severe)],
            lvef: "severe",
            expected: [.valvular, .hemodynamic, .endocarditis, .ventricular]
        )
    }

    func testTransplantWithMCSDevice() {
        assertCategories(.heartTransplant, [], expected: [.transplant])
        assertCategories(.lvad, [.ventricularFunction], expected: [.mcs, .ventricular])
    }
}
