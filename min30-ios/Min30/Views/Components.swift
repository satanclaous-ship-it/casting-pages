import SwiftUI

// MARK: - 1–5 척도

/// Number *and* word on every step: the value never rides on position alone,
/// and the tap targets stay thumb-sized.
struct ScalePicker: View {
    let labels: [String]
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { v in
                Button {
                    value = (value == v) ? 0 : v
                } label: {
                    VStack(spacing: 1) {
                        Text("\(v)")
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                        Text(labels[v - 1])
                            .font(.system(size: 10))
                            .foregroundStyle(value == v ? .secondary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(value == v ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(value == v ? Color.accentColor : .clear, lineWidth: 1)
                    )
                    .foregroundStyle(value == v ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 카드 · 라벨

struct Card<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(.tertiary)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                // proportional figures — tabular makes big numbers look loose
                Text(value).font(.system(size: 21, weight: .semibold))
                if let unit {
                    Text(unit).font(.system(size: 12)).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

struct MicButton: View {
    let dictation: Dictation
    var large = false
    var seed: () -> String
    var onText: (String) -> Void

    var body: some View {
        Button {
            if dictation.isRecording {
                dictation.stop()
            } else {
                dictation.reset()
                dictation.start(seed: seed())
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.fill")
                Text(dictation.isRecording ? "듣는 중… 탭하면 끝" : (large ? "말해서 기록하기" : "음성으로"))
            }
            .font(.system(size: large ? 14 : 12.5))
            .frame(maxWidth: large ? .infinity : nil, minHeight: large ? 48 : 34)
            .padding(.horizontal, large ? 12 : 13)
            .background(dictation.isRecording ? Color.red.opacity(0.22) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: large ? 12 : 999))
            .foregroundStyle(dictation.isRecording ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!dictation.isAvailable)
        .opacity(dictation.isAvailable ? 1 : 0.45)
        .onChange(of: dictation.transcript) { _, new in
            if !new.isEmpty { onText(new) }
        }
    }
}

/// Wraps items to as many rows as they need — the tag grid and legends both
/// want this and neither wants a fixed column count.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct LegendChip: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label).font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
    }
}

struct Insight: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text(icon)
            Text(text).font(.system(size: 13))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func cardStack() -> some View {
        self.padding(.horizontal, 16)
    }
}
