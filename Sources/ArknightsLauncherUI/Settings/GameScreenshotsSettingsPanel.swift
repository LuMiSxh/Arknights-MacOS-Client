// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct GameScreenshotsSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let screenshots: GameScreenshotController

	var body: some View {
		SettingsPanel(title: "Screenshots") {
			SettingsActionRow(
				title: "Shortcut",
				detail: "Saves a picture of the game window while the game runs.",
				help:
					"The launcher needs Screen Recording access. macOS may ask you to confirm it again from time to time. After you allow it, you may need to restart the launcher."
			) {
				GlassMenuPicker(
					selection: $settings.screenshotShortcut,
					options: ScreenshotShortcut.allCases.map { ($0, Self.title(for: $0)) }
				)
			}
			if screenshots.isPermissionDenied {
				SettingsHairline()
				SettingsActionRow(
					title: "Screen Recording is off for Arknights Client."
				) {
					CapsuleActionButton(
						title: "Open System Settings",
						systemImage: "gearshape",
						tone: .neutral,
						action: screenshots.openSystemScreenRecordingSettings
					)
				}
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Save to",
				detail: "Screenshots keep their names and are never overwritten."
			) {
				GlassActionMenu(title: folderTitle, systemImage: "folder") {
					Button("Pictures/\(AppConstants.Screenshots.defaultFolderName)") {
						settings.screenshotDirectory = nil
					}
					Button("Choose Folder…", action: chooseFolder)
				}
				.accessibilityLabel("Save to")
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Notify when saved",
				detail: "Shows a banner with a Show in Finder button."
			) {
				SettingsToggle("Notify when saved", isOn: $settings.screenshotNotifies)
			}
		}
		.onAppear { screenshots.refreshPermission() }
		.onReceive(
			NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
		) {
			_ in screenshots.refreshPermission()
		}
	}

	private var folderTitle: String {
		settings.screenshotDirectory?.lastPathComponent
			?? "Pictures/\(AppConstants.Screenshots.defaultFolderName)"
	}

	private func chooseFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.prompt = "Choose"
		panel.begin { response in
			guard response == .OK, let url = panel.url else { return }
			Task { @MainActor in settings.screenshotDirectory = url }
		}
	}

	private static func title(for shortcut: ScreenshotShortcut) -> String {
		switch shortcut {
		case .off: "Off"
		case .controlOptionS: "⌃⌥S"
		case .f13: "F13"
		case .controlOptionCommandS: "⌃⌥⌘S"
		}
	}
}
