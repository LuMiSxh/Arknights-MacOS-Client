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
	@State private var model: LauncherViewModel

	init() {
		var arguments = ProcessInfo.processInfo.arguments
		#if DEBUG
			if DeveloperScenario(arguments: arguments) == nil,
				Bundle.main.object(forInfoDictionaryKey: "DeveloperPreviewEnabled") as? Bool
					== true
			{
				arguments += ["--developer-scenario", DeveloperScenario.ready.rawValue]
			}
			if DeveloperScenario(arguments: arguments) != nil {
				let root = FileManager.default.temporaryDirectory.appending(
					path: "ArknightsClientPreview",
					directoryHint: .isDirectory
				)
				let paths = AppPaths(
					applicationSupportDirectory: root.appending(path: "Support"),
					cachesDirectory: root.appending(path: "Caches"),
					libraryDirectory: root.appending(path: "Library")
				)
				let defaults = UserDefaults(suiteName: "com.lumisxh.arknights-client.preview")!
				_model = State(
					wrappedValue: LauncherViewModel(
						paths: paths,
						preferences: LauncherPreferencesStore(defaults: defaults),
						arguments: arguments
					)
				)
				return
			}
		#endif
		_model = State(wrappedValue: LauncherViewModel(arguments: arguments))
	}

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
