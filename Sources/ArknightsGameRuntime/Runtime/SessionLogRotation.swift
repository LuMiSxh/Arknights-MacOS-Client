// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Keeps the previous game session's logs for diagnostics.
///
/// The Wine log is appended to and Unity truncates its log at start, so without a rotation the
/// logs of a crashed session are gone after the next launch. Each launch moves a non-empty log
/// to `*.previous.log` and replaces the older copy.
enum SessionLogRotation {
	@concurrent
	static func rotate(region: GameRegion, paths: AppPaths, log: LauncherLog) async {
		for file in [paths.runtimeLogFile(for: region), paths.unityLogFile] {
			log.attempt("Rotating \(file.lastPathComponent)") {
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
		do {
			try fileManager.removeItem(at: previous)
		} catch  where AppPaths.isMissingPathError(error) {
			// No earlier session log to replace.
		}
		try fileManager.moveItem(at: file, to: previous)
	}
}
