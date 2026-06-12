import SwiftUI

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
            .accessibilityLabel("Status: \(text)")
    }
}

struct PanelHeader: View {
    let title: String
    let systemImage: String
    var accessory: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Brand.accent)
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct UsageMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    var isUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(isUnavailable ? .secondary : .primary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .padding(14)
        .brandedPanel(cornerRadius: 16)
    }
}

struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SmallMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct UsageSplitBar: View {
    let share: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Brand.accent.opacity(0.22))
                Capsule()
                    .fill(Brand.accentSecondary)
                    .frame(width: proxy.size.width * share)
            }
        }
        .frame(height: 9)
        .overlay(alignment: .bottomLeading) {
            HStack {
                Text("BYOK")
                Spacer()
                Text("OpenRouter")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .offset(y: 18)
        }
        .padding(.bottom, 18)
    }
}

struct EmptyPanelMessage: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Brand.warning)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct ProminentActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Brand.actionGradient, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
