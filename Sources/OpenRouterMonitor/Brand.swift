import AppKit
import SwiftUI

enum Brand {
    static let accent = Color(red: 0.18, green: 0.58, blue: 1.0)
    static let accentSecondary = Color(red: 0.18, green: 0.84, blue: 0.62)
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.24)
    static let danger = Color(red: 1.0, green: 0.32, blue: 0.36)
    static let panelStroke = Color.primary.opacity(0.09)
    static let panelLift = Color.primary.opacity(0.045)

    static var panelFill: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var windowBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var actionGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.88)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var iconImage: NSImage? {
        if let appURL = Bundle.main.url(forResource: "OpenRouterIcon", withExtension: "png") {
            return NSImage(contentsOf: appURL)
        }

        if let moduleURL = Bundle.module.url(forResource: "OpenRouterIcon", withExtension: "png") {
            return NSImage(contentsOf: moduleURL)
        }

        return nil
    }
}

struct BrandIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            if let image = Brand.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "arrow.triangle.branch")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Brand.accent)
                    .scaledToFit()
                    .frame(width: size * 0.72, height: size * 0.72)
            }
        }
                .frame(width: size, height: size, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.18), style: .continuous))
        .contentShape(Rectangle())
        .accessibilityLabel("OpenRouter")
    }
}

struct BrandedPanel: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Brand.panelFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Brand.panelLift)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Brand.panelStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func brandedPanel(cornerRadius: CGFloat = 18) -> some View {
        modifier(BrandedPanel(cornerRadius: cornerRadius))
    }
}
