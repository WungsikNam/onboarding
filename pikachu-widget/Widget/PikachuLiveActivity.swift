import ActivityKit
import SwiftUI
import WidgetKit

typealias LiveState = PikachuActivityAttributes.ContentState

/// Pikachu next to the status bar: Dynamic Island on supported iPhones, banner on the Lock Screen.
struct PikachuLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PikachuActivityAttributes.self) { context in
            LockScreenPetView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(context.state.isSleeping
                    ? Color(red: 0.14, green: 0.15, blue: 0.33)
                    : Color(red: 1.0, green: 0.93, blue: 0.62))
                .activitySystemActionForegroundColor(PetColors.ink)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PikachuSprite(look: state.look)
                        .frame(width: 58, height: 58)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lv.\(state.level)").font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(PetColors.xp)
                        Text(state.mood.emoji + (state.poops > 0 ? " 💩×\(state.poops)" : ""))
                            .font(.system(size: 13))
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.name).font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text(context.isStale ? "앱을 열면 상태를 새로 확인해요" : state.speech)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        LiveStatBars(state: state)
                        LiveActionRow(state: state, dark: true)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                PikachuSprite(look: state.headLook)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                FullnessRing(state: state)
            } minimal: {
                PikachuSprite(look: state.headLook)
                    .frame(width: 20, height: 20)
            }
            .keylineTint(PetColors.xp)
        }
    }
}

// MARK: - Live bars

/// A bar that drains (or fills) by itself between Live Activity updates.
private struct LiveStatBar: View {
    let icon: String
    let color: Color
    let value: Double
    let range: ClosedRange<Date>
    var countsDown = true

    var body: some View {
        HStack(spacing: 5) {
            Text(icon).font(.system(size: 11))
            Group {
                // Once the range is over the bar would sit at its end, so draw the settled value instead.
                if range.upperBound > .now {
                    ProgressView(timerInterval: range, countsDown: countsDown) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                } else {
                    ProgressView(value: countsDown ? 0 : 1)
                }
            }
            .tint(value < 25 ? .red : color)
        }
    }
}

private struct LiveStatBars: View {
    let state: LiveState

    var body: some View {
        HStack(spacing: 10) {
            LiveStatBar(icon: "🍎", color: PetColors.fullness, value: state.fullness, range: state.fullnessRange)
            LiveStatBar(icon: "💗", color: PetColors.happiness, value: state.happiness, range: state.happinessRange)
            LiveStatBar(icon: "⚡", color: PetColors.energy, value: state.energy, range: state.energyRange,
                        countsDown: !state.isSleeping)
        }
    }
}

/// Compact trailing view: a ring showing how full Pikachu is, emptying in real time.
private struct FullnessRing: View {
    let state: LiveState

    var body: some View {
        Group {
            if state.fullnessRange.upperBound > .now {
                ProgressView(timerInterval: state.fullnessRange, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: 0)
            }
        }
        .progressViewStyle(.circular)
        .tint(state.fullness < 25 ? .red : PetColors.xp)
        .overlay {
            Text(state.isSleeping ? "💤" : state.mood == .hungry ? "🍎" : "⚡")
                .font(.system(size: 9))
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Buttons

private struct LiveActionRow: View {
    let state: LiveState
    var dark: Bool

    var body: some View {
        HStack(spacing: 6) {
            button(.feed)
            button(.play)
            button(.pet)
            button(state.poops > 0 ? .clean : .sleep)
        }
    }

    private func button(_ action: PetAction) -> some View {
        Button(intent: CareIntent(action)) {
            HStack(spacing: 3) {
                Text(action == .sleep && state.isSleeping ? "☀️" : action.emoji).font(.system(size: 13))
                Text(action == .sleep && state.isSleeping ? "깨우기" : action.label)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .foregroundStyle(dark ? .white : PetColors.ink)
            .background(dark ? Color.white.opacity(0.14) : Color.white.opacity(0.7),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock Screen banner

private struct LockScreenPetView: View {
    let state: LiveState
    let isStale: Bool

    var body: some View {
        let textColor = state.isSleeping ? Color.white : PetColors.ink
        HStack(spacing: 12) {
            PikachuSprite(look: state.look)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(state.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text("Lv.\(state.level)").font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(PetColors.xp, in: Capsule())
                        .foregroundStyle(PetColors.ink)
                    Spacer()
                    Text(isStale ? "⏳" : state.speech)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                LiveStatBars(state: state)
                LiveActionRow(state: state, dark: state.isSleeping)
            }
            .foregroundStyle(textColor)
        }
        .padding(14)
    }
}

// MARK: - Previews

#Preview("Island", as: .dynamicIsland(.expanded), using: PikachuActivityAttributes()) {
    PikachuLiveActivity()
} contentStates: {
    LiveState(.preview)
}

#Preview("Compact", as: .dynamicIsland(.compact), using: PikachuActivityAttributes()) {
    PikachuLiveActivity()
} contentStates: {
    LiveState(.preview)
}

#Preview("Lock Screen", as: .content, using: PikachuActivityAttributes()) {
    PikachuLiveActivity()
} contentStates: {
    LiveState(.preview)
}
