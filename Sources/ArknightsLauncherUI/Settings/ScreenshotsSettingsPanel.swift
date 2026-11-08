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
				detail: "Saves a picture of the game window while the game runs.",
				help:
					"The launcher needs Screen Recording access. macOS may ask you to confirm it again from time to time. After you allow it, you may need to restart the launcher."
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
				if settings.screenshotNotifies, screenshots.isNotificationAccessDenied {
					SettingsHairline()
					SettingsActionRow(
						title: "Notifications are off for Arknights Client."
					) {
						CapsuleActionButton(
							title: "Open System Settings",
							systemImage: "gearshape",
							tone: .neutral,
							action: openNotificationSettings
						)
					}
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
