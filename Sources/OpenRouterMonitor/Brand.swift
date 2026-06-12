import AppKit
import SwiftUI

enum Brand {
    static let accent = Color(red: 0.18, green: 0.58, blue: 1.0)
    static let accentSecondary = Color(red: 0.18, green: 0.84, blue: 0.62)
    static let warning = Color(red: 1.0, green: 0.68, blue: 0.24)
    static let danger = Color(red: 1.0, green: 0.32, blue: 0.36)
    static let panelStroke = Color.primary.opacity(0.10)
    static let elevatedFill = Color.primary.opacity(0.045)

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
            colors: [accent, accentSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.060),
                Color.primary.opacity(0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
        .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.18)))
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
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Brand.panelStroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Brand.panelGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Brand.panelStroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
        }
    }
}

extension View {
    func brandedPanel(cornerRadius: CGFloat = 18) -> some View {
        modifier(BrandedPanel(cornerRadius: cornerRadius))
    }
}
