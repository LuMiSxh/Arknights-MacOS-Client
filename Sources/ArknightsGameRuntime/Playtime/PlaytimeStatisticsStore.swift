// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation
import Synchronization

// Persists playtime statistics off the main actor. Save failures are logged; a load failure
// starts from `.empty`.
struct PlaytimeStatisticsStore: Sendable {
	let fileURL: URL
	let log: LauncherLog

	// Orders writes. Once the termination write seals it, an older in-flight snapshot is dropped.
	private final class WriteGate: Sendable {
		let isSealed = Mutex(false)
	}

	private let gate = WriteGate()
	private let files = JSONFileStore(
		maximumBytes: AppConstants.Playtime.statisticsMaximumBytes,
		iso8601Dates: true
	)

	init(fileURL: URL, log: LauncherLog) {
		self.fileURL = fileURL
		self.log = log
	}

	/// Returns `.empty` when the file is missing or unreadable. An unreadable file moves aside.
	@concurrent
	func load() async -> PlaytimeStatistics {
		loadSynchronously()
	}

	@concurrent
	func save(_ statistics: PlaytimeStatistics) async {
		write(statistics, sealing: false)
	}

	/// For application termination, where nothing can await the asynchronous path.
	func loadSynchronously() -> PlaytimeStatistics {
		do {
			return try readStatistics()
		} catch {
			logFailure(error, operation: "load")
			moveUnreadableFileAside()
			return .empty
		}
	}

	/// Writes the final snapshot and drops every later `save`, so an older one cannot overwrite it.
	func saveSynchronously(_ statistics: PlaytimeStatistics) {
		write(statistics, sealing: true)
	}

	private func write(_ statistics: PlaytimeStatistics, sealing: Bool) {
		gate.isSealed.withLock { isSealed in
			guard sealing || !isSealed else { return }
			isSealed = isSealed || sealing
			do {
				try files.write(statistics, to: fileURL, createParentDirectory: true)
			} catch {
				logFailure(error, operation: "save")
			}
		}
	}

	private func readStatistics() throws -> PlaytimeStatistics {
		do {
			return try files.read(PlaytimeStatistics.self, at: fileURL)?.validated() ?? .empty
		} catch BoundedFileReadError.tooLarge {
			throw PlaytimeStatisticsError.fileTooLarge
		}
	}

	// Keeps unreadable statistics, for example after a downgrade, from being overwritten.
	private func moveUnreadableFileAside() {
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: fileURL.path) else { return }
		let asideURL = fileURL.appendingPathExtension("unreadable")
		do {
			if fileManager.fileExists(atPath: asideURL.path) {
				try fileManager.removeItem(at: asideURL)
			}
			try fileManager.moveItem(at: fileURL, to: asideURL)
		} catch {
			logFailure(error, operation: "preserve unreadable")
		}
	}

	private func logFailure(_ error: Error, operation: String) {
		log.error("Could not \(operation) local playtime statistics: \(error.localizedDescription)")
	}
}
