import SwiftUI
import WidgetKit

// MARK: - Timeline

struct PetEntry: TimelineEntry {
    let date: Date
    let state: PetState
}

struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, state: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: .now, state: context.isPreview ? .preview : PetStore.shared.load()))
    }

    /// Widgets can't run code on their own, so precompute how Pikachu will look over the next hours.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let now = Date.now
        let state = PetStore.shared.load(at: now)
        var dates = stride(from: 0.0, through: 6 * 3600, by: 15 * 60).map { now.addingTimeInterval($0) }
        if let expires = state.reaction?.expires { dates.append(expires) }
        let entries = dates.sorted().map { PetEntry(date: $0, state: state.advanced(to: $0)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget

struct PikachuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PikachuWidget", provider: PetProvider()) { entry in
            PikachuWidgetView(state: entry.state)
        }
        .configurationDisplayName("피카츄 키우기")
        .description("밥 주고, 놀아주고, 재워주세요. 버튼을 눌러 바로 돌볼 수 있어요.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct PikachuWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let state: PetState

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory { Color.clear } else { PetBackground(sleeping: state.isSleeping) }
            }
    }

    private var isAccessory: Bool {
        let accessories: [WidgetFamily] = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        return accessories.contains(family)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium: MediumPetView(state: state)
        case .systemLarge: LargePetView(state: state)
        case .accessoryCircular: CircularPetView(state: state)
        case .accessoryRectangular: RectangularPetView(state: state)
        case .accessoryInline: InlinePetView(state: state)
        default: SmallPetView(state: state)
        }
    }
}

// MARK: - Pieces

private struct CareButton: View {
    let action: PetAction
    let state: PetState
    var compact = false

    var body: some View {
        Button(intent: CareIntent(action)) {
            ActionLabel(action: action, isSleeping: state.isSleeping, compact: compact)
        }
        .buttonStyle(.plain)
    }
}

/// Tapping Pikachu pets it.
private struct PettableScene: View {
    let state: PetState

    var body: some View {
        Button(intent: CareIntent(.pet)) {
            PetScene(state: state)
        }
        .buttonStyle(.plain)
    }
}

private struct Header: View {
    let state: PetState

    var body: some View {
        HStack(spacing: 4) {
            Text(state.name).font(.system(size: 13, weight: .heavy, design: .rounded)).lineLimit(1)
            Spacer(minLength: 0)
            Text("Lv.\(state.level)").font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(PetColors.xp, in: Capsule())
        }
        .foregroundStyle(state.isSleeping ? .white : PetColors.ink)
    }
}

private struct StatBars: View {
    let state: PetState
    var height: CGFloat = 7

    var body: some View {
        VStack(spacing: height * 0.6) {
            StatBar(icon: "🍎", value: state.fullness, color: PetColors.fullness, height: height)
            StatBar(icon: "💗", value: state.happiness, color: PetColors.happiness, height: height)
            StatBar(icon: "⚡", value: state.energy, color: PetColors.energy, height: height)
        }
    }
}

/// The action that matters most right now, for widgets with room for only one extra button.
private func urgentAction(_ state: PetState) -> PetAction {
    if state.poops > 0 { return .clean }
    if state.isSleeping || state.energy < 30 { return .sleep }
    return .pet
}

// MARK: - Home Screen

private struct SmallPetView: View {
    let state: PetState

    var body: some View {
        VStack(spacing: 4) {
            Header(state: state)
            ZStack(alignment: .top) {
                PettableScene(state: state).padding(.top, 14)
                SpeechBubble(text: state.speech, font: .system(size: 9, weight: .semibold))
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 4) {
                CareButton(action: .feed, state: state, compact: true)
                CareButton(action: .play, state: state, compact: true)
                CareButton(action: urgentAction(state), state: state, compact: true)
            }
        }
    }
}

private struct MediumPetView: View {
    let state: PetState

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                SpeechBubble(text: state.speech)
                PettableScene(state: state)
            }
            .frame(maxWidth: 130)

            VStack(alignment: .leading, spacing: 6) {
                Header(state: state)
                StatBars(state: state)
                HStack(spacing: 4) {
                    CareButton(action: .feed, state: state)
                    CareButton(action: .play, state: state)
                    CareButton(action: .sleep, state: state)
                    CareButton(action: .clean, state: state)
                }
            }
        }
    }
}

private struct LargePetView: View {
    let state: PetState

    var body: some View {
        VStack(spacing: 10) {
            Header(state: state)
            HStack(spacing: 6) {
                Text("\(state.stage.displayName) · 함께한 지 \(state.daysTogether)일째")
                Spacer()
                Text("\(state.mood.emoji) \(state.mood.label)")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(state.isSleeping ? .white.opacity(0.85) : PetColors.ink.opacity(0.7))

            VStack(spacing: 4) {
                SpeechBubble(text: state.speech, font: .footnote.weight(.semibold))
                PettableScene(state: state)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 6) {
                StatBars(state: state, height: 9)
                StatBar(icon: "⭐️", value: state.xpProgress * 100, color: PetColors.xp, height: 5)
            }
            .padding(10)
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 5) {
                ForEach(PetAction.allCases, id: \.self) { action in
                    CareButton(action: action, state: state)
                }
            }
        }
    }
}

// MARK: - Lock Screen

private struct CircularPetView: View {
    let state: PetState

    var body: some View {
        Gauge(value: state.fullness, in: 0...100) {
            Text("🍎")
        } currentValueLabel: {
            PikachuSprite(look: PikachuLook(state, headOnly: true)).padding(5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

private struct RectangularPetView: View {
    let state: PetState

    var body: some View {
        HStack(spacing: 6) {
            PikachuSprite(look: PikachuLook(state, headOnly: true))
                .frame(width: 34)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.name) Lv.\(state.level)").font(.headline).lineLimit(1)
                Text("\(state.mood.emoji) \(state.mood.label)").font(.caption).lineLimit(1)
                HStack(spacing: 3) {
                    ProgressView(value: state.fullness, total: 100)
                    ProgressView(value: state.happiness, total: 100)
                    ProgressView(value: state.energy, total: 100)
                }
            }
        }
    }
}

private struct InlinePetView: View {
    let state: PetState

    var body: some View {
        Text("⚡ \(state.name) \(state.mood.emoji) \(state.mood.label)")
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PikachuWidget()
} timeline: {
    PetEntry(date: .now, state: .preview)
}

#Preview(as: .systemMedium) {
    PikachuWidget()
} timeline: {
    PetEntry(date: .now, state: .preview)
}
