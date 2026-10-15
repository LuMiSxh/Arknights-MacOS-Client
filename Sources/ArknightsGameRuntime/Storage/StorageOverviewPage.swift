// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

/// English copy and descriptions supplied by the Settings feature.
package struct StorageOverviewCopy {
	let title: String
	let subtitle: String
	let installationsTitle: String
	let sharedTitle: String
	let cachesTitle: String
	let logsTitle: String
	let calculating: String
	let unavailable: String
	let clearCaches: String
	let clearGalleryCache: String
	let showLogs: String
	let categoryTitle: (StorageCategory) -> String
	let categoryDetail: (StorageCategory) -> String

	package static var english: StorageOverviewCopy {
		StorageOverviewCopy(
			title: "Storage",
			subtitle: "Disk usage and targeted cleanup",
			installationsTitle: "Game Installations",
			sharedTitle: "Shared Runtime Data",
			cachesTitle: "Recreatable Caches",
			logsTitle: "Logs",
			calculating: "Calculating…",
			unavailable: "Not present",
			clearCaches: "Clear Caches",
			clearGalleryCache: "Clear Gallery Cache",
			showLogs: "Show Logs",
			categoryTitle: { category in
				switch category {
				case .game(let region): region.displayName
				case .winePrefix: "Game Environment"
				case .compatibilityRuntime: "Compatibility Runtime"
				case .dxmtCache: "DXMT Shader Cache"
				case .browserCache: "Embedded Browser Data"
				case .galleryCache: "Preset Gallery Caches"
				case .logs: "Logs"
				}
			},
			categoryDetail: { category in
				switch category {
				case .game: "Game files that may require repair or reinstall."
				case .winePrefix:
					"Shared by the selected publisher's servers; contains runtime data and logins."
				case .compatibilityRuntime: "Bundled Wine and DXMT components; read-only."
				case .dxmtCache: "Recreated automatically and removed by the cache cleanup action."
				case .browserCache:
					"Recreated automatically and removed by the cache cleanup action."
				case .galleryCache:
					"Clear cached preset metadata and all downloaded avatars and wallpapers."
				case .logs: "Launcher and game diagnostics; reveal them in Finder."
				}
			}
		)
	}
}

/// Targeted actions for the storage buckets. No generic path deletion is exposed.
package struct StorageOverviewActions {
	let clearGameCaches: () -> Void
	let clearGalleryCache: () -> Void
	let revealLogs: () -> Void

	package init(
		clearGameCaches: @escaping () -> Void,
		clearGalleryCache: @escaping () -> Void,
		revealLogs: @escaping () -> Void
	) {
		self.clearGameCaches = clearGameCaches
		self.clearGalleryCache = clearGalleryCache
		self.revealLogs = revealLogs
	}
}

package struct StorageOverviewPage: View {
	let controller: StorageOverviewController
	let copy: StorageOverviewCopy
	package let actions: StorageOverviewActions
	package let accentColor: Color

	package init(
		controller: StorageOverviewController,
		copy: StorageOverviewCopy,
		actions: StorageOverviewActions,
		accentColor: Color
	) {
		self.controller = controller
		self.copy = copy
		self.actions = actions
		self.accentColor = accentColor
	}

	package var body: some View {
		SettingsPage(title: copy.title, subtitle: copy.subtitle, accentColor: accentColor) {
			if !gameUsages.isEmpty {
				SettingsPanel(title: copy.installationsTitle, systemImage: "square.stack.3d.up") {
					ForEach(gameUsages) { usage in
						usageRow(usage)
					}
				}
			}

			SettingsPanel(title: copy.sharedTitle, systemImage: "externaldrive") {
				ForEach(sharedUsages) { usage in
					usageRow(usage)
				}
			}

			SettingsPanel(title: copy.cachesTitle, systemImage: "archivebox") {
				ForEach(cacheUsages) { usage in
					usageRow(usage)
				}
				SettingsHairline()
				HStack(spacing: 8) {
					CapsuleActionButton(
						title: copy.clearCaches,
						systemImage: "trash",
						tone: .danger,
						presentation: .compact,
						role: .destructive,
						action: actions.clearGameCaches
					)
					CapsuleActionButton(
						title: copy.clearGalleryCache,
						systemImage: "trash",
						tone: .danger,
						presentation: .compact,
						role: .destructive,
						action: actions.clearGalleryCache
					)
				}
				.disabled(!controller.canModifyStorage)
			}

			SettingsPanel(title: copy.logsTitle, systemImage: "doc.text.magnifyingglass") {
				if let usage = controller.usage(for: .logs) {
					usageRow(usage) {
						actions.revealLogs()
					}
				}
			}

		}
		.onAppear(perform: controller.refresh)
	}

	private var gameUsages: [StorageUsage] {
		usages(where: {
			guard case .game = $0.location.category else { return false }
			return $0.exists
		})
	}

	private var sharedUsages: [StorageUsage] {
		usages(where: {
			switch $0.location.category {
			case .game, .dxmtCache, .browserCache, .galleryCache, .logs: false
			case .winePrefix, .compatibilityRuntime: true
			}
		})
	}

	private var cacheUsages: [StorageUsage] {
		usages(where: {
			switch $0.location.category {
			case .dxmtCache, .browserCache, .galleryCache: true
			default: false
			}
		})
	}

	private func usages(where predicate: (StorageUsage) -> Bool) -> [StorageUsage] {
		controller.usages.filter(predicate)
	}

	@ViewBuilder
	private func usageRow(_ usage: StorageUsage, action: (() -> Void)? = nil) -> some View {
		SettingsActionRow(
			title: copy.categoryTitle(usage.location.category),
			detail: copy.categoryDetail(usage.location.category)
		) {
			HStack(spacing: 12) {
				sizeView(for: usage)

				if let action {
					CapsuleActionButton(
						title: copy.showLogs,
						systemImage: "doc.text.magnifyingglass",
						tone: .neutral,
						presentation: .compact,
						action: action
					)
				}
			}
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
		guard let byteCount = usage.byteCount else {
			return controller.isMeasuring ? copy.calculating : copy.unavailable
		}
		guard usage.exists else { return copy.unavailable }
		return DownloadProgressFormatting.byteCount(byteCount)
	}
}
