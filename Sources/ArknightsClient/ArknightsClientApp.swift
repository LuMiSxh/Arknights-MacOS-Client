import SwiftUI

@main
struct ArknightsClientApp: App {
  @StateObject private var model = LauncherViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        .frame(minWidth: 880, minHeight: 560)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1040, height: 680)
  }
}
