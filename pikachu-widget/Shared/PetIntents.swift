import AppIntents
import WidgetKit

extension PetAction: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "돌보기"
    static let caseDisplayRepresentations: [PetAction: DisplayRepresentation] = [
        .feed: "밥 주기",
        .play: "놀아주기",
        .pet: "쓰다듬기",
        .sleep: "재우기 / 깨우기",
        .clean: "청소하기",
    ]
}

/// Every button (widget, Dynamic Island, Lock Screen, Siri) goes through this intent.
/// As a LiveActivityIntent it runs in the app's process, so it can also start/update the Live Activity.
struct CareIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "피카츄 돌보기"
    static let description = IntentDescription("피카츄에게 밥을 주거나 놀아주거나 재워요.")

    @Parameter(title: "행동")
    var action: PetAction

    init() {}

    init(_ action: PetAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = PetStore.shared.apply(action)
        await StatusBarPet.sync(state)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "\(state.speech)")
    }
}

/// Puts Pikachu back in the Dynamic Island (e.g. after the system ended the Live Activity).
struct ShowInStatusBarIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "피카츄 상태바에 띄우기"

    func perform() async throws -> some IntentResult {
        PetStore.shared.statusBarEnabled = true
        await StatusBarPet.sync(PetStore.shared.load())
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
