// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameSessionController {
	func refreshRuntime() {
		do {
			runtimeName = try discoverRuntime().displayName
		} catch {
			runtimeName = nil
			Task { [log] in
				await log.error("Runtime discovery failed: \(error.localizedDescription)")
			}
		}
	}

	func forcePrefixMigration() {
		guard lifecycle.activity == .idle else { return }
		do {
			try RuntimeMigrationStore().reset(prefixDirectory: paths.winePrefix)
			lifecycle.setStatus(
				.custom(L10n.string(.Launcher.launcherStatusWineMigrationPending)))
			Task { [log] in
				await log.info("Wine prefix migration state was reset on request")
			}
		} catch {
			lifecycle.show(error)
		}
	}

	func deleteWinePrefix() {
		guard lifecycle.activity == .idle else { return }
		let prefixDirectory = paths.winePrefix
		guard FileManager.default.fileExists(atPath: prefixDirectory.path) else { return }
		lifecycle.activity = .maintaining(.deletingWinePrefix)
		lifecycle.setStatus(
			.custom(L10n.string(.Launcher.launcherStatusWinePrefixDeleting)))
		Task { [weak self] in
			guard let self else { return }
			do {
				try await Task.detached(priority: .userInitiated) {
					try FileManager.default.removeItem(at: prefixDirectory)
				}.value
				lifecycle.activity = .idle
				lifecycle.setStatus(
					.custom(L10n.string(.Launcher.launcherStatusWineMigrationDeleted)))
				await log.info("Wine prefix deleted on request")
			} catch {
				lifecycle.activity = .idle
				lifecycle.show(error)
			}
		}
	}

	func discoverRuntime() throws -> WineRuntime {
		try WineRuntime.discover(compatibilityManager: gameCompatibilityManager)
	}
}
