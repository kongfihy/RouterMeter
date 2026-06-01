import AppKit
import SwiftUI

enum Brand {
    static let accent = Color(red: 0.29, green: 0.63, blue: 1.0)
    static let accentSecondary = Color(red: 0.18, green: 0.86, blue: 0.75)
    static let panelFill = Color(red: 0.08, green: 0.10, blue: 0.13).opacity(0.72)
    static let panelStroke = Color.white.opacity(0.10)

    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.16, blue: 0.21).opacity(0.82),
                Color(red: 0.07, green: 0.09, blue: 0.12).opacity(0.78)
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
    func body(content: Content) -> some View {
        content
            .background(Brand.panelGradient, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Brand.panelStroke, lineWidth: 1)
            )
    }
}

extension View {
    func brandedPanel() -> some View {
        modifier(BrandedPanel())
    }
}
