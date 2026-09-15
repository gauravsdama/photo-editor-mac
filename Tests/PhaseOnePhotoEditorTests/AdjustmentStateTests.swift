import Testing
@testable import PhaseOnePhotoEditor

@Suite("Adjustment state")
struct AdjustmentStateTests {
    @Test("Values clamp to the supported range")
    func valuesClamp() {
        var state = AdjustmentState()
        state.setValue(99, for: .exposure)
        #expect(state.value(for: .exposure) == 4)
    }

    @Test("Reset restores neutral values")
    func resetRestoresDefaults() {
        var state = AdjustmentState()
        state.setValue(0.5, for: .contrast)
        state.reset()
        #expect(state.value(for: .contrast) == 0)
        #expect(state.value(for: .saturation) == 1)
    }
}
