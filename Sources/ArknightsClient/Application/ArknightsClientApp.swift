// SPDX-License-Identifier: MPL-2.0

import SwiftUI

@main
struct ArknightsClientApp: App {
	@StateObject private var model = LauncherViewModel()

	var body: some Scene {
		WindowGroup("Arknights Client") {
			ContentView(model: model)
				.frame(minWidth: 880, minHeight: 560)
		}
		.windowStyle(.hiddenTitleBar)
		.defaultSize(width: 1040, height: 680)
	}
}
