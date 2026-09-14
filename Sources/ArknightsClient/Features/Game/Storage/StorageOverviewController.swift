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
	private let regionProvider: @MainActor () -> GameRegion
	@ObservationIgnored private var measurementTask: Task<Void, Never>?
	@ObservationIgnored private var measurementEpoch: UInt64 = 0
	@ObservationIgnored private var lastMeasuredContext: StorageOverviewContext?
	@ObservationIgnored private var lastMeasuredAt: Date?

	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog,
		regionProvider: @escaping @MainActor () -> GameRegion = { .global }
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.preferences = preferences
		self.log = log
		self.regionProvider = regionProvider
		usages = []
	}

	deinit {
		measurementTask?.cancel()
	}

	var canModifyStorage: Bool {
		lifecycle.activity == .idle
	}

	func refresh() {
		startMeasurement(force: false)
	}

	func refreshNow() {
		startMeasurement(force: true)
	}

	private func startMeasurement(force: Bool) {
		let context = StorageOverviewResolver.context(
			preferences: preferences,
			region: regionProvider()
		)
		if !force {
			if isMeasuring { return }
			if hasFreshMeasurement(for: context) { return }
		}

		measurementEpoch &+= 1
		let epoch = measurementEpoch
		measurementTask?.cancel()
		if lastMeasuredContext != context {
			usages = StorageOverviewResolver.placeholderLocations(context: context).map {
				StorageUsage(location: $0, byteCount: nil, exists: false)
			}
		}
		isMeasuring = true
		let paths = self.paths
		let log = self.log

		measurementTask = Task { [weak self, log] in
			let measurement = Task.detached(priority: .utility) {
				let locations = StorageOverviewResolver.locations(paths: paths, context: context)
				return try StorageSizeCalculator.measure(locations)
			}
			do {
				let measured = try await withTaskCancellationHandler(
					operation: {
						try await measurement.value
					},
					onCancel: {
						measurement.cancel()
					})
				guard !Task.isCancelled, let self, self.measurementEpoch == epoch else { return }
				self.usages = measured
				self.lastMeasuredContext = context
				self.lastMeasuredAt = Date()
				self.isMeasuring = false
				self.measurementTask = nil
			} catch is CancellationError {
				guard let self, self.measurementEpoch == epoch else { return }
				self.isMeasuring = false
				self.measurementTask = nil
			} catch {
				guard let self, self.measurementEpoch == epoch else { return }
				self.isMeasuring = false
				self.measurementTask = nil
				await log.error("Failed to measure launcher storage: \(error.localizedDescription)")
			}
		}
	}

	private func hasFreshMeasurement(for context: StorageOverviewContext) -> Bool {
		guard
			!usages.isEmpty,
			lastMeasuredContext == context,
			let lastMeasuredAt
		else { return false }
		return Date().timeIntervalSince(lastMeasuredAt)
			< AppConstants.Storage.overviewCacheLifetime
	}

	func usage(for category: StorageCategory) -> StorageUsage? {
		usages.first { $0.location.category == category }
	}
}
