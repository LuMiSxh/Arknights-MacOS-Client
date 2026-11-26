// SPDX-License-Identifier: MPL-2.0

import Foundation

extension RuntimeInstaller {
	/// Builds the pinned runtime in `staging` from the installed one and the pinned delta whose
	/// `from` is the installed version. Returns nil when no delta applies or any step fails, so the
	/// caller installs the full archive instead. Cancellation is not a failure and still throws.
	func prepareFromDelta(
		pin: PinnedRuntime,
		staging: URL,
		progress: @escaping ProgressHandler
	) async throws -> PreparedRuntime? {
		guard let installed = store.installedVersion(for: pin.lane),
			let delta = pin.deltas.first(where: { $0.from == installed })
		else { return nil }

		let source = paths.runtimeVersionDirectory(for: pin.lane, version: installed)
		let extractedDelta = Self.extractedDelta(in: staging)
		let target = Self.deltaTarget(in: staging)
		let totalBytes = Int64(delta.asset.sizeBytes)
		do {
			// The clone is nearly free; the budget covers the delta, its extracted copy, and the temporary tar.
			try checkDiskSpace(required: totalBytes * 4)
			let partURL = try await download(delta.asset, lane: pin.lane, progress: progress)

			await progress(
				RuntimeInstallProgress(
					downloadedBytes: totalBytes, totalBytes: totalBytes, phase: .extracting))
			let deltaRoot = try RuntimeArchive.extract(
				at: partURL, into: extractedDelta, expectedRoot: RuntimeArchive.deltaRoot,
				fileManager: FileManager.default)
			let plan = try RuntimeDeltaPlan.load(
				deltaRoot: deltaRoot, lane: pin.lane, from: installed, to: pin.version)
			try checkDiskSpace(required: plan.targetBytes)
			try await RuntimeDeltaApplier.apply(
				plan: plan, deltaRoot: deltaRoot, source: source, target: target)
			return PreparedRuntime(root: target, totalBytes: totalBytes)
		} catch {
			try Task.checkCancellation()
			log?.error(
				.runtime, "delta-failed", ["from": installed, "version": pin.version],
				error: error)
			discardDeltaStaging(in: staging)
			return nil
		}
	}

	/// Removes the trees of a delta attempt that will not be installed.
	func discardDeltaStaging(in staging: URL) {
		bestEffort("delta-staging-discard") {
			for url in [Self.extractedDelta(in: staging), Self.deltaTarget(in: staging)]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
		}
	}

	private static func extractedDelta(in staging: URL) -> URL {
		staging.appending(path: "delta", directoryHint: .isDirectory)
	}

	private static func deltaTarget(in staging: URL) -> URL {
		staging.appending(path: "runtime", directoryHint: .isDirectory)
	}
}
