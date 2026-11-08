// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension LauncherViewModel {
	/// Builds the launcher's model for the app entry point. A developer preview clears a
	/// fixed preference store on every start, so previews never accumulate domains or temp
	/// folders.
	package static func makeDefault() -> LauncherViewModel {
		let arguments = ProcessInfo.processInfo.arguments
		#if DEBUG
			if DeveloperSimulationState.isPreviewArgument(arguments) {
				let suiteName = "com.lumisxh.arknights-client.preview"
				let root = FileManager.default.temporaryDirectory.appending(
					path: "ArknightsClientPreview",
					directoryHint: .isDirectory
				)
				do {
					if FileManager.default.fileExists(atPath: root.path) {
						try FileManager.default.removeItem(at: root)
					}
				} catch {
					NSLog("ArknightsClient could not clear the previous preview data: \(error)")
				}
				let paths = AppPaths(
					applicationSupportDirectory: root.appending(path: "Support"),
					cachesDirectory: root.appending(path: "Caches"),
					libraryDirectory: root.appending(path: "Library")
				)
				let defaults = UserDefaults(suiteName: suiteName)!
				defaults.removePersistentDomain(forName: suiteName)
				return LauncherViewModel(
					paths: paths,
					preferences: LauncherPreferencesStore(defaults: defaults),
					arguments: arguments
				)
			}
		#endif
		PreferencesMigrator().migrate(.standard)
		return LauncherViewModel(
			paths: AppPaths(),
			preferences: LauncherPreferencesStore(),
			arguments: arguments
		)
	}
}
