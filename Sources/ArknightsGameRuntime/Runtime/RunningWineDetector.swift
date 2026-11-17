// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Darwin
import Foundation

/// Finds a Wine process the launcher did not start. A layout migration must not rename game or
/// environment folders under a running game, so it asks this before it moves anything.
package struct RunningWineDetector: Sendable {
	package typealias ProcessPathSource = @Sendable () -> [(pid: Int32, path: String)]

	private let roots: [URL]
	private let processPaths: ProcessPathSource

	/// 0.6/0.7 builds put their Wine under `Contents/Resources/Runtime`; `runtimeRoot` holds the
	/// managed trees. Under `swift run` the bundle has no such directory, so only `runtimeRoot` matches.
	package init(
		paths: AppPaths,
		bundleURL: URL = Bundle.main.bundleURL,
		processPaths: @escaping ProcessPathSource = RunningWineDetector.liveProcessPaths
	) {
		roots = [
			bundleURL.appending(
				path: AppConstants.Runtime.legacyBundledRuntimeRelativePath,
				directoryHint: .isDirectory
			),
			paths.runtimeRoot,
		]
		self.processPaths = processPaths
	}

	@concurrent
	package func isRunning() async -> Bool {
		let roots = roots.map { Self.canonicalURL($0).pathComponents }
		let ownProcessIdentifier = getpid()
		for process in processPaths() where process.pid != ownProcessIdentifier {
			let components = Self.canonicalURL(URL(filePath: process.path)).pathComponents
			if roots.contains(where: { components.starts(with: $0) }) { return true }
		}
		return false
	}

	// Standardizing and resolving links makes an aliased runtime folder compare like the real one.
	private static func canonicalURL(_ url: URL) -> URL {
		url.standardizedFileURL.resolvingSymlinksInPath()
	}

	// `PROC_PIDPATHINFO_MAXSIZE` is not exported to Swift; libproc defines it as 4 * MAXPATHLEN.
	private static let processPathBufferSize = Int(MAXPATHLEN) * 4

	/// Resolves every live process to its executable. PIDs that exited or cannot be read are skipped.
	package static func liveProcessPaths() -> [(pid: Int32, path: String)] {
		let capacity = Int(proc_listallpids(nil, 0)) + 16
		guard capacity > 16 else { return [] }
		var pids = [pid_t](repeating: 0, count: capacity)
		let listed = proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.size))
		guard listed > 0 else { return [] }

		var result: [(pid: Int32, path: String)] = []
		for pid in pids[0..<min(capacity, Int(listed))] where pid > 0 {
			var buffer = [UInt8](repeating: 0, count: Self.processPathBufferSize)
			let written = proc_pidpath(pid, &buffer, UInt32(buffer.count))
			guard written > 0 else { continue }
			result.append((Int32(pid), String(decoding: buffer[0..<Int(written)], as: UTF8.self)))
		}
		return result
	}
}
