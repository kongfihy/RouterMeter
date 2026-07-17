import SwiftUI

enum RouterMotion {
    static let dashboardReveal = Animation.easeOut(duration: 0.17)
    static let sectionChange = Animation.smooth(duration: 0.21)
    static let valueChange = Animation.smooth(duration: 0.18)
    static let quickFade = Animation.easeOut(duration: 0.14)
}

private struct AnimatedNumericTextModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : RouterMotion.valueChange, value: value)
    }
}

extension View {
    func animatedNumericText(value: String) -> some View {
        modifier(AnimatedNumericTextModifier(value: value))
    }
}
