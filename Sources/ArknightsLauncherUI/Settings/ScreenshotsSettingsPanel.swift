// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct ScreenshotsSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let screenshots: GameScreenshotController
	let openNotificationSettings: () -> Void
	@State private var isRecordingShortcut = false

	var body: some View {
		SettingsPanel(title: "Screenshots") {
			SettingsActionRow(
				title: "Shortcut",
				detail:
					"Saves a picture of the game window while the game runs. Needs Screen Recording access; you may need to restart the launcher after allowing it.",
				help:
					"macOS may ask you to confirm Screen Recording access again from time to time."
			) {
				if isRecordingShortcut {
					ScreenshotShortcutRecorder(
						onRecord: { shortcut in
							settings.screenshotShortcut = shortcut
							isRecordingShortcut = false
						},
						onCancel: { isRecordingShortcut = false })
				} else {
					GlassMenuPicker(
						selection: $settings.screenshotShortcut,
						options: shortcutOptions,
						listTitle: { $0 == .standard ? "⌃⌥S (Default)" : nil },
						trailingMenuItems: {
							Divider()
							Button("Record Shortcut…") { isRecordingShortcut = true }
						})
				}
			}
			if screenshots.isPermissionDenied {
				SettingsHairline()
				SettingsStatusRow(
					label: "Screen Recording is off for Arknights Client",
					actionTitle: "Open System Settings",
					action: screenshots.openSystemScreenRecordingSettings
				)
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
			if settings.screenshotNotifies, screenshots.isNotificationAccessDenied {
				SettingsHairline()
				SettingsStatusRow(
					label: "Notifications are off for Arknights Client",
					actionTitle: "Open System Settings",
					action: openNotificationSettings
				)
			}
		}
		.onAppear {
			screenshots.refreshPermission()
			Task { await screenshots.refreshNotificationAccess() }
		}
		.onReceive(
			NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
		) {
			_ in
			screenshots.refreshPermission()
			Task { await screenshots.refreshNotificationAccess() }
		}
		.onChange(of: settings.screenshotNotifies) { _, isOn in
			guard isOn else { return }
			Task { await screenshots.refreshNotificationAccess() }
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

	/// Off and the default shortcut, plus the recorded shortcut while one is set.
	private var shortcutOptions: [(value: ScreenshotShortcut, title: String)] {
		var shortcuts: [ScreenshotShortcut] = [.off, .standard]
		if case .custom = settings.screenshotShortcut {
			shortcuts.append(settings.screenshotShortcut)
		}
		return shortcuts.map { (value: $0, title: $0.displayName) }
	}
}
