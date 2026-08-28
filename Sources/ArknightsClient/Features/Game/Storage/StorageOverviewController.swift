// SPDX-License-Identifier: MPL-2.0

import Foundation
import Observation

/// Measures app-owned storage without blocking Settings and exposes only targeted maintenance
/// state. Destructive operations remain owned by the installation, runtime, and cache features.
@MainActor
@Observable
final class StorageOverviewController {
	private(set) var usages: [StorageUsage]
	private(set) var isMeasuring = false

	let lifecycle: LauncherLifecycleStore
	private let paths: AppPaths
	private let preferences: LauncherPreferencesStore
	private let log: LauncherLog
	@ObservationIgnored private var measurementTask: Task<Void, Never>?

	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.preferences = preferences
		self.log = log
		usages = []
	}

	deinit {
		measurementTask?.cancel()
	}

	var canModifyStorage: Bool {
		lifecycle.activity == .idle
	}

	func refresh() {
		measurementTask?.cancel()
		let resolvedLocations = StorageOverviewResolver.locations(
			paths: paths,
			preferences: preferences
		)
		usages = resolvedLocations.map {
			StorageUsage(location: $0, byteCount: nil, exists: false)
		}
		isMeasuring = true
		let log = self.log

		measurementTask = Task { [weak self, log] in
			let measurement = Task.detached(priority: .utility) {
				try StorageSizeCalculator.measure(resolvedLocations)
			}
			do {
				let measured = try await withTaskCancellationHandler(
					operation: {
						try await measurement.value
					},
					onCancel: {
						measurement.cancel()
					})
				guard !Task.isCancelled else { return }
				self?.usages = measured
				self?.isMeasuring = false
			} catch is CancellationError {
				self?.isMeasuring = false
			} catch {
				self?.isMeasuring = false
				await log.error("Failed to measure launcher storage: \(error.localizedDescription)")
			}
		}
	}

	func usage(for category: StorageCategory) -> StorageUsage? {
		usages.first { $0.location.category == category }
	}
}
