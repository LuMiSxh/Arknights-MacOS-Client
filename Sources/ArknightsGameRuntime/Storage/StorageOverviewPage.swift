// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import SwiftUI

/// Targeted actions for the storage buckets. No generic path deletion is exposed.
package struct StorageOverviewActions {
	let clearGameCaches: () -> Void
	let clearGalleryCache: () -> Void
	let revealLogs: () -> Void
	let revealApplicationSupport: () -> Void

	package init(
		clearGameCaches: @escaping () -> Void,
		clearGalleryCache: @escaping () -> Void,
		revealLogs: @escaping () -> Void,
		revealApplicationSupport: @escaping () -> Void
	) {
		self.clearGameCaches = clearGameCaches
		self.clearGalleryCache = clearGalleryCache
		self.revealLogs = revealLogs
		self.revealApplicationSupport = revealApplicationSupport
	}
}

package struct StorageOverviewPage: View {
	let controller: StorageOverviewController
	package let actions: StorageOverviewActions

	package init(controller: StorageOverviewController, actions: StorageOverviewActions) {
		self.controller = controller
		self.actions = actions
	}

	package var body: some View {
		SettingsPage(title: "Storage", subtitle: "Disk usage and targeted cleanup") {
			if !gameUsages.isEmpty {
				SettingsPanel(title: "Game installations") {
					ForEach(gameUsages) { usage in
						usageRow(usage, title: regionName(for: usage))
					}
				}
			}

			SettingsPanel(title: "Shared runtime data") {
				if let usage = controller.usage(for: .winePrefix) {
					usageRow(
						usage,
						title: "Game environment",
						detail:
							"Shared by one publisher’s servers. Holds sign-ins and Windows settings."
					)
				}
				if let usage = controller.usage(for: .compatibilityRuntime) {
					usageRow(
						usage,
						title: "Runtime",
						detail: "Bundled files that run the game. Read-only."
					)
				}
			}

			SettingsPanel(title: "Recreatable caches") {
				if let usage = controller.usage(for: .dxmtCache) {
					usageRow(
						usage,
						title: "Shader cache",
						detail: "Graphics data. Recreated automatically."
					)
				}
				if let usage = controller.usage(for: .browserCache) {
					usageRow(
						usage,
						title: "Sign-in window data",
						detail: "Cached pages for the sign-in window. Recreated automatically."
					)
				}
				if let usage = controller.usage(for: .galleryCache) {
					usageRow(
						usage,
						title: "Preset gallery",
						detail: "Cached preset metadata, avatars, and wallpapers."
					)
				}
				SettingsActionRow(
					title: "Shader and sign-in window caches",
					detail: "Removes both caches. The next game start is slower."
				) {
					CapsuleActionButton(
						title: "Clear Caches",
						systemImage: "trash",
						tone: .neutral,
						presentation: .compact,
						action: actions.clearGameCaches
					)
					.disabled(!controller.canModifyStorage)
				}
				SettingsActionRow(
					title: "Downloaded artwork",
					detail:
						"Removes the cached preset data and all downloaded avatars and wallpapers."
				) {
					CapsuleActionButton(
						title: "Clear Gallery Cache",
						systemImage: "trash",
						tone: .neutral,
						presentation: .compact,
						action: actions.clearGalleryCache
					)
					.disabled(!controller.canModifyStorage)
				}
				if !controller.canModifyStorage,
					let reason = controller.lifecycle.activity.lockReason
				{
					SettingsFootnote(reason)
				}
			}

			SettingsPanel(title: "Logs and data") {
				if let usage = controller.usage(for: .logs) {
					SettingsActionRow(
						title: "Logs",
						detail:
							"Launcher and game logs. Show them in Finder when a maintainer asks."
					) {
						sizeView(for: usage)
						ExternalLinkButton(title: "Show Logs", action: actions.revealLogs)
					}
				}
				SettingsActionRow(
					title: "App Data Folder",
					detail: "Opens the folder with settings, logs, runtimes, and game environments."
				) {
					ExternalLinkButton(
						title: "Show in Finder",
						action: actions.revealApplicationSupport
					)
				}
			}

			SettingsPanel(title: "Measurements") {
				SettingsActionRow(
					title: "Refresh sizes",
					detail:
						"Measures every size on this page again. Sizes update in the background."
				) {
					CapsuleActionButton(
						title: controller.isMeasuring ? "Measuring…" : "Refresh",
						systemImage: "arrow.clockwise",
						tone: .neutral,
						presentation: .compact,
						action: controller.refreshNow
					)
					.disabled(controller.isMeasuring)
				}
			}
		}
		.onAppear(perform: controller.refresh)
	}

	private var gameUsages: [StorageUsage] {
		controller.usages.filter { usage in
			guard case .game = usage.location.category else { return false }
			return usage.exists
		}
	}

	private func regionName(for usage: StorageUsage) -> String {
		guard case .game(let region) = usage.location.category else { return "" }
		return region.displayName
	}

	private func usageRow(_ usage: StorageUsage, title: String, detail: String? = nil) -> some View
	{
		SettingsActionRow(title: title, detail: detail) {
			sizeView(for: usage)
		}
	}

	/// Keeps the row's geometry stable while a measurement is pending instead of showing text.
	@ViewBuilder
	private func sizeView(for usage: StorageUsage) -> some View {
		if usage.byteCount == nil, controller.isMeasuring {
			SkeletonValue(width: 60, height: 16)
		} else {
			Text(sizeText(for: usage))
				.font(.callout.monospacedDigit().weight(.semibold))
				.multilineTextAlignment(.trailing)
				.fixedSize(horizontal: true, vertical: false)
		}
	}

	private func sizeText(for usage: StorageUsage) -> String {
		guard usage.exists else { return "None" }
		guard let byteCount = usage.byteCount else { return "Unavailable" }
		return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
	}
}
