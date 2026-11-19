// SPDX-License-Identifier: MPL-2.0

import Darwin
import Dispatch
import Foundation
import Testing

/// Suspends until `ready` holds, re-checking it whenever an entry in `url`'s parent directory changes.
///
/// Use this for state the code under test reaches by creating, renaming or removing a file.
/// Writing bytes into an existing file does not notify, so such a state cannot end the wait.
/// The parent directory may not exist yet; the wait then watches its nearest existing ancestor.
/// If no ancestor can be opened, this returns at once and the caller's assertions fail.
/// After `timeout` the wait records an issue and returns, so a missing change fails instead of hanging.
package func waitForDirectoryChange(
	containing url: URL,
	timeout: Duration = .seconds(10),
	sourceLocation: SourceLocation = #_sourceLocation,
	until ready: @escaping @Sendable () -> Bool
) async {
	let deadline = ContinuousClock.now.advanced(by: timeout)
	let parent = url.deletingLastPathComponent()
	while true {
		guard let watched = nearestExistingDirectory(from: parent) else { return }
		let descriptor = open(watched.path, O_EVTONLY)
		guard descriptor >= 0 else { return }
		let changed = Signal()
		let source = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: descriptor,
			eventMask: .write,
			queue: .global()
		)
		source.setEventHandler { changed.fire() }
		source.setCancelHandler { _ = close(descriptor) }
		source.resume()
		// Check after the source is live, so a change made before `resume()` is not missed.
		// A deeper directory created before arming raises no event on `watched`, so re-arm on it.
		let isCurrent = nearestExistingDirectory(from: parent)?.path == watched.path
		if isCurrent {
			if ready() {
				source.cancel()
				return
			}
			let remaining = max(.zero, ContinuousClock.now.duration(to: deadline))
			let changedInTime = await changed.wait(timeout: remaining)
			if !changedInTime {
				source.cancel()
				if !ready() {
					Issue.record("No change within \(timeout)", sourceLocation: sourceLocation)
				}
				return
			}
		}
		source.cancel()
		if isCurrent, ready() { return }
	}
}

private func nearestExistingDirectory(from directory: URL) -> URL? {
	var candidate = directory
	while true {
		var isDirectory: ObjCBool = false
		if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
			isDirectory.boolValue
		{
			return candidate
		}
		let parent = candidate.deletingLastPathComponent()
		if parent.path == candidate.path { return nil }
		candidate = parent
	}
}

/// Suspends until a file exists at `url`.
package func waitForFile(
	at url: URL,
	timeout: Duration = .seconds(10),
	sourceLocation: SourceLocation = #_sourceLocation
) async {
	await waitForDirectoryChange(
		containing: url,
		timeout: timeout,
		sourceLocation: sourceLocation
	) {
		FileManager.default.fileExists(atPath: url.path)
	}
}
