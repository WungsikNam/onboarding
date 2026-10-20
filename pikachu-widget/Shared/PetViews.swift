import SwiftUI

enum PetColors {
    static let fullness = Color(red: 1.0, green: 0.55, blue: 0.25)
    static let happiness = Color(red: 1.0, green: 0.42, blue: 0.55)
    static let energy = Color(red: 0.25, green: 0.65, blue: 1.0)
    static let xp = Color(red: 1.0, green: 0.8, blue: 0.0)
    static let ink = Color(red: 0.17, green: 0.17, blue: 0.17)
}

/// Sky by day, night sky while Pikachu sleeps.
struct PetBackground: View {
    var sleeping: Bool

    var body: some View {
        LinearGradient(
            colors: sleeping
                ? [Color(red: 0.12, green: 0.14, blue: 0.32), Color(red: 0.24, green: 0.22, blue: 0.45)]
                : [Color(red: 0.62, green: 0.85, blue: 1.0), Color(red: 1.0, green: 0.96, blue: 0.78)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// A small labeled progress bar for one stat (0–100).
struct StatBar: View {
    var icon: String
    var value: Double
    var color: Color
    var height: CGFloat = 7

    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: height + 4))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.12))
                    Capsule().fill(value < 25 ? .red : color)
                        .frame(width: max(height, geo.size.width * value / 100))
                }
            }
            .frame(height: height)
        }
    }
}

struct SpeechBubble: View {
    var text: String
    var font: Font = .caption2.weight(.semibold)

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(PetColors.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(PetColors.ink.opacity(0.15)))
    }
}

/// Pikachu plus its surroundings: Zzz while sleeping, poops on the floor.
struct PetScene: View {
    var state: PetState
    /// Size of the Zzz / poop decorations; widgets use the small default.
    var decorationSize: CGFloat = 10

    var body: some View {
        PikachuSprite(look: PikachuLook(state))
            .scaleEffect(state.stage == .pichu ? 0.82 : 1, anchor: .bottom)
            .overlay(alignment: .topTrailing) {
                if state.isSleeping {
                    Text("z Z").font(.system(size: decorationSize * 1.1, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(x: 4, y: -2)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if state.poops > 0 {
                    Text(String(repeating: "💩", count: state.poops))
                        .font(.system(size: decorationSize))
                        .offset(x: -4, y: 2)
                }
            }
    }
}

struct ActionLabel: View {
    var action: PetAction
    var isSleeping: Bool
    var compact = false

    var body: some View {
        let emoji = action == .sleep && isSleeping ? "☀️" : action.emoji
        let label = action == .sleep && isSleeping ? "깨우기" : action.label
        VStack(spacing: 1) {
            Text(emoji).font(.system(size: compact ? 15 : 17))
            if !compact {
                Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(PetColors.ink.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 28 : 36)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
