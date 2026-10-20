import BackgroundTasks
import SwiftUI
import WidgetKit

@main
struct PikachuPetApp: App {
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.pikachupet.refresh"

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Self.scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            // Keeps the Dynamic Island face/speech fresh while the app is closed.
            Self.scheduleRefresh()
            let state = PetStore.shared.load()
            PetStore.shared.save(state)
            await StatusBarPet.sync(state, startIfNeeded: false)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date.now.addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
