import ActivityKit
import Foundation

/// The Live Activity that keeps Pikachu in the Dynamic Island and on the Lock Screen.
struct PikachuActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var name: String
        var level: Int
        var stage: PetStage
        var mood: PetMood
        var reaction: ReactionKind?
        var speech: String
        var fullness: Double
        var happiness: Double
        var energy: Double
        var isSleeping: Bool
        var poops: Int
        var xpProgress: Double
        // Live Activities only redraw when updated, so bars are driven by date ranges that
        // the system animates on its own (see LiveStatBar).
        var fullnessRange: ClosedRange<Date>
        var happinessRange: ClosedRange<Date>
        var energyRange: ClosedRange<Date>

        init(_ s: PetState) {
            name = s.name
            level = s.level
            stage = s.stage
            mood = s.mood
            reaction = s.reaction?.kind
            speech = s.speech
            fullness = s.fullness
            happiness = s.happiness
            energy = s.energy
            isSleeping = s.isSleeping
            poops = s.poops
            xpProgress = s.xpProgress

            let fullnessRate = s.isSleeping ? PetRules.fullnessDecayAsleep : PetRules.fullnessDecayAwake
            let fullnessEnd = s.fullnessEmptyDate
            fullnessRange = fullnessEnd.addingTimeInterval(-100 / fullnessRate * 3600)...fullnessEnd
            let happinessEnd = s.happinessEmptyDate
            happinessRange = happinessEnd.addingTimeInterval(-100 / s.currentHappinessDecay * 3600)...happinessEnd
            energyRange = s.energyWindow
        }

        var look: PikachuLook {
            PikachuLook(stage: stage, mood: mood, reaction: reaction, level: level)
        }

        var headLook: PikachuLook {
            PikachuLook(stage: stage, mood: mood, reaction: reaction, level: level, headOnly: true)
        }
    }
}

/// Starts, updates and ends the Live Activity.
enum StatusBarPet {
    private static var running: [Activity<PikachuActivityAttributes>] {
        Activity<PikachuActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    static var isRunning: Bool { !running.isEmpty }

    static var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Pushes `state` to the running activity. When none is running and the user wants Pikachu in
    /// the status bar, starts one (Live Activities end on their own after ~8 hours).
    static func sync(_ state: PetState, startIfNeeded: Bool = true) async {
        let content = ActivityContent(
            state: PikachuActivityAttributes.ContentState(state),
            staleDate: Date.now.addingTimeInterval(4 * 3600)
        )
        let activities = running
        if activities.isEmpty {
            guard startIfNeeded, PetStore.shared.statusBarEnabled, isAllowed else { return }
            // Only succeeds from the app or a LiveActivityIntent; fails quietly elsewhere.
            _ = try? Activity<PikachuActivityAttributes>.request(attributes: PikachuActivityAttributes(), content: content, pushType: nil)
        } else {
            for activity in activities {
                await activity.update(content)
            }
        }
    }

    static func stop() async {
        for activity in Activity<PikachuActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
