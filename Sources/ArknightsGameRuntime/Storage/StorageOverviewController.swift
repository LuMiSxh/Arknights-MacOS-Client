// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Observation

/// Measures app-owned storage without blocking Settings and exposes only targeted maintenance
/// state. Destructive operations remain owned by the installation, runtime, and cache features.
@MainActor
@Observable
package final class StorageOverviewController {
	private(set) var usages: [StorageUsage]
	package private(set) var isMeasuring = false

	let lifecycle: LauncherLifecycleStore
	private let paths: AppPaths
	private let preferences: LauncherPreferencesStore
	private let log: LauncherLog
	private let regionProvider: @MainActor () -> GameRegion
	@ObservationIgnored private let measurementSlot = TaskSlot()
	@ObservationIgnored private let cacheStore: StorageOverviewCacheStore
	@ObservationIgnored private var cachedEntries: [StorageOverviewCacheEntry]
	@ObservationIgnored private var pendingCacheWrite: Task<Void, Never>?
	/// The context whose values `usages` shows, whether cached or measured.
	@ObservationIgnored private var displayedContext: StorageOverviewContext?
	@ObservationIgnored private var lastMeasuredContext: StorageOverviewContext?
	@ObservationIgnored private var lastMeasuredAt: Date?

	package init(
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
		let cacheStore = StorageOverviewCacheStore(
			fileURL: paths.storageOverviewCache,
			log: log
		)
		self.cacheStore = cacheStore
		cachedEntries = cacheStore.loadSynchronously()
		usages = []
		// Seed from the cache now, so the first Settings frame already shows sizes.
		let context = StorageOverviewResolver.context(
			preferences: preferences,
			region: regionProvider()
		)
		usages = displayedUsages(for: context)
		displayedContext = context
	}

	var canModifyStorage: Bool {
		lifecycle.activity == .idle
	}

	func refresh() {
		startMeasurement(force: false)
	}

	package func refreshNow() {
		startMeasurement(force: true)
	}

	@concurrent
	private static func measure(
		paths: AppPaths,
		context: StorageOverviewContext
	) async throws -> [StorageUsage] {
		let locations = try StorageOverviewResolver.locations(paths: paths, context: context)
		return try StorageSizeCalculator.measure(locations)
	}

	private func startMeasurement(force: Bool) {
		let context = StorageOverviewResolver.context(
			preferences: preferences,
			region: regionProvider()
		)
		if displayedContext != context {
			// Work for the previous context must not publish over the values shown now.
			measurementSlot.invalidate()
			isMeasuring = false
			usages = displayedUsages(for: context)
			displayedContext = context
		}
		if !force {
			if isMeasuring || hasFreshMeasurement(for: context) { return }
		}

		isMeasuring = true
		let paths = self.paths
		let log = self.log

		measurementSlot.replace { [weak self, log] token in
			do {
				let measured = try await Self.measure(paths: paths, context: context)
				guard !Task.isCancelled, let self, self.measurementSlot.owns(token) else { return }
				self.finishMeasurement(measured, for: context)
			} catch is CancellationError {
				guard let self, self.measurementSlot.owns(token) else { return }
				self.isMeasuring = false
			} catch {
				guard let self, self.measurementSlot.owns(token) else { return }
				self.isMeasuring = false
				log.error("Failed to measure launcher storage: \(error.localizedDescription)")
			}
		}
	}

	private func finishMeasurement(
		_ measured: [StorageUsage],
		for context: StorageOverviewContext
	) {
		isMeasuring = false
		lastMeasuredContext = context
		lastMeasuredAt = Date()
		// Skip the publish when nothing changed, so Observation does not redraw the page.
		if usages.map(CachedStorageUsage.init) != measured.map(CachedStorageUsage.init) {
			usages = measured
		}
		let entry = StorageOverviewCacheEntry(
			key: StorageOverviewCacheKey(context: context),
			usages: measured.map(CachedStorageUsage.init)
		)
		guard cachedEntries.first(where: { $0.key == entry.key }) != entry else { return }
		cachedEntries.removeAll { $0.key == entry.key }
		cachedEntries.insert(entry, at: 0)
		cachedEntries = Array(cachedEntries.prefix(AppConstants.Storage.overviewCacheEntryLimit))
		persistCachedEntries(cachedEntries)
	}

	/// Seeds the page with the last measurement for `context`, or with placeholders.
	private func displayedUsages(for context: StorageOverviewContext) -> [StorageUsage] {
		let key = StorageOverviewCacheKey(context: context)
		let cached = cachedEntries.first { $0.key == key }?.usages ?? []
		return StorageOverviewResolver.placeholderLocations(context: context).map { location in
			let entry = cached.first { $0.categoryID == location.category.id }
			return StorageUsage(
				location: location,
				byteCount: entry?.byteCount,
				exists: entry?.exists ?? false
			)
		}
	}

	/// Writes are chained so an older snapshot cannot land after a newer one.
	private func persistCachedEntries(_ entries: [StorageOverviewCacheEntry]) {
		let previousWrite = pendingCacheWrite
		let store = cacheStore
		pendingCacheWrite = Task {
			await previousWrite?.value
			await store.save(entries)
		}
	}

	private func hasFreshMeasurement(for context: StorageOverviewContext) -> Bool {
		guard
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
