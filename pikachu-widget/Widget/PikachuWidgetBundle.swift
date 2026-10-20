import SwiftUI
import WidgetKit

@main
struct PikachuWidgetBundle: WidgetBundle {
    var body: some Widget {
        PikachuWidget()
        PikachuLiveActivity()
    }
}
