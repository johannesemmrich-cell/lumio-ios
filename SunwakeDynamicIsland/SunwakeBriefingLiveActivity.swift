import ActivityKit
import WidgetKit
import SwiftUI

struct SunwakeBriefingWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunwakeBriefingAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenBriefingView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.horizon.fill")
                            .foregroundStyle(Color(hex: context.attributes.accentColorHex))
                            .font(.caption)
                        Text("Sunwake")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        Text("\(context.state.currentIndex + 1)/\(context.state.totalItems)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor, isActive: context.state.isPlaying)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.currentItemTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !context.state.currentItemTime.isEmpty {
                            Text(context.state.currentItemTime)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(.white)
                            .scaleEffect(x: 1, y: 0.6)

                        if let next = context.state.nextItemTitle {
                            HStack {
                                Text("Next:")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text(next)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(Color(hex: context.attributes.accentColorHex))
                    .font(.caption)
            } compactTrailing: {
                HStack(spacing: 3) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor, isActive: context.state.isPlaying)
                    Text(context.state.currentItemTitle)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: 80)
                }
            } minimal: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(Color(hex: context.attributes.accentColorHex))
                    .font(.caption2)
            }
            .keylineTint(Color(hex: context.attributes.accentColorHex))
        }
    }
}

// MARK: — Color hex helper (widget-target copy)

private extension Color {
    init(hex hexString: String) {
        let hex = UInt32(hexString.trimmingCharacters(in: .init(charactersIn: "#")), radix: 16) ?? 0xFF9500
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}

// MARK: — Lock Screen Banner

struct LockScreenBriefingView: View {
    let context: ActivityViewContext<SunwakeBriefingAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: context.attributes.accentColorHex).opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(Color(hex: context.attributes.accentColorHex))
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Sunwake Briefing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(context.state.currentItemTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if !context.state.currentItemTime.isEmpty {
                    Text(context.state.currentItemTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(context.state.isPlaying ? Color(hex: context.attributes.accentColorHex) : .secondary)
                    .symbolEffect(.variableColor, isActive: context.state.isPlaying)
                Text("\(context.state.currentIndex + 1)/\(context.state.totalItems)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
