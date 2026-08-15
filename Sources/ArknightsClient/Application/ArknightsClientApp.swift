// SPDX-License-Identifier: MPL-2.0

import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	var stopGame: (() -> Void)?

	func applicationWillTerminate(_ notification: Notification) {
		stopGame?()
	}
}

@main
struct ArknightsClientApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var model = LauncherViewModel()

	var body: some Scene {
		WindowGroup("Arknights Client") {
			ContentView(model: model)
				.frame(minWidth: 880, minHeight: 560)
				.onAppear {
					appDelegate.stopGame = model.stopGameForApplicationTermination
				}
		}
		.windowStyle(.hiddenTitleBar)
		.defaultSize(width: 1040, height: 680)
	}
}
