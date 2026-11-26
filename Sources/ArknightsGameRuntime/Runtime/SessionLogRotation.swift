// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Keeps the last three game session logs for diagnostics.
///
/// The Wine log is appended to and Unity truncates its log at start, so without a rotation the
/// logs of a crashed session are gone after the next launch. Each launch shifts the two older
/// non-empty logs back and moves the newest to `*.previous.log`.
enum SessionLogRotation {
	@concurrent
	static func rotate(region: GameRegion, paths: AppPaths, log: LauncherLog) async {
		for file in [paths.runtimeLogFile(for: region), paths.unityLogFile] {
			log.attempt(.session, "log-rotate") {
				try rotate(file)
			}
		}
	}

	static func rotate(_ file: URL, fileManager: FileManager = .default) throws {
		let size: NSNumber?
		do {
			size = try fileManager.attributesOfItem(atPath: file.path)[.size] as? NSNumber
		} catch  where AppPaths.isMissingPathError(error) {
			return
		}
		guard size?.intValue ?? 0 > 0 else { return }
		let previous = AppPaths.previousLogFile(of: file)
		let previousSecond = AppPaths.previousSecondLogFile(of: file)
		do {
			try fileManager.removeItem(at: previousSecond)
		} catch  where AppPaths.isMissingPathError(error) {
			// No log from two sessions ago to replace.
		}
		do {
			try fileManager.moveItem(at: previous, to: previousSecond)
		} catch  where AppPaths.isMissingPathError(error) {
			// The oldest kept session has no log to shift.
		}
		try fileManager.moveItem(at: file, to: previous)
	}
}
