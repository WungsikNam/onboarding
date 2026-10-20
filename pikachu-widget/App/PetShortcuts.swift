import AppIntents

/// Siri / Shortcuts / Action Button: "피카츄 밥 주기", "피카츄 놀아주기" …
struct PetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CareIntent(),
            phrases: [
                "\(.applicationName) \(\.$action)",
                "\(.applicationName)한테 \(\.$action)",
                "\(.applicationName) 돌보기",
            ],
            shortTitle: "피카츄 돌보기",
            systemImageName: "bolt.heart.fill"
        )
        AppShortcut(
            intent: ShowInStatusBarIntent(),
            phrases: ["\(.applicationName) 상태바에 띄워줘"],
            shortTitle: "상태바에 띄우기",
            systemImageName: "rectangle.topthird.inset.filled"
        )
    }
}
