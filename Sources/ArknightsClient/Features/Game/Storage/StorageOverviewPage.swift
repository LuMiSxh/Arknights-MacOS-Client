// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Localized copy and descriptions supplied by the Settings feature.
struct StorageOverviewCopy {
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
}

/// Targeted actions for the storage buckets. No generic path deletion is exposed.
struct StorageOverviewActions {
	let clearGameCaches: () -> Void
	let clearGalleryCache: () -> Void
	let revealLogs: () -> Void
}

struct StorageOverviewPage: View {
	let controller: StorageOverviewController
	let copy: StorageOverviewCopy
	let actions: StorageOverviewActions
	let accentColor: Color

	var body: some View {
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
						tone: .accent(accentColor),
						presentation: .compact,
						action: actions.clearGameCaches
					)
					CapsuleActionButton(
						title: copy.clearGalleryCache,
						systemImage: "trash",
						tone: .accent(accentColor),
						presentation: .compact,
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
				Text(sizeText(for: usage))
					.font(.callout.monospacedDigit().weight(.semibold))
					.multilineTextAlignment(.trailing)
					.fixedSize(horizontal: true, vertical: false)

				if let action {
					CapsuleActionButton(
						title: copy.showLogs,
						systemImage: "doc.text.magnifyingglass",
						tone: .accent(accentColor),
						presentation: .compact,
						action: action
					)
				}
			}
		}
	}

	private func sizeText(for usage: StorageUsage) -> String {
		guard let byteCount = usage.byteCount else {
			return controller.isMeasuring ? copy.calculating : copy.unavailable
		}
		guard usage.exists else { return copy.unavailable }
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: byteCount)
	}
}
