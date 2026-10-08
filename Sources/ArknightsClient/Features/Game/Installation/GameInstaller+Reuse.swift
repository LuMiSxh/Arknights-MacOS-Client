// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// A complete installation of another region whose files may be cloned instead of downloaded.
///
/// Sources are only read: the installer never opens them through `InstallerInstallDirectory`,
/// so it takes no lock and no file in them is modified, moved, or held open beyond one clone.
struct ReuseSource: Sendable {
	let directory: URL
	/// Paths the source's own installed state lists, or `nil` for a state recorded before
	/// file metadata existed.
	let knownPaths: Set<String>?

	func mayContain(_ relativePath: String) -> Bool {
		knownPaths?.contains(relativePath) ?? true
	}
}

/// What one operation took from other regions, summarized once the operation finishes.
actor ReuseTally {
	private(set) var files = 0
	private(set) var bytes: Int64 = 0

	func record(bytes: Int64) {
		files += 1
		self.bytes += bytes
	}
}

struct ReuseSession: Sendable {
	let sources: [ReuseSource]
	let tally = ReuseTally()

	static var none: ReuseSession { ReuseSession(sources: []) }
}

extension GameInstaller {
	/// Resolves the other regions that can donate files to `target`. A candidate must be a
	/// different directory from the target and have both `Arknights.exe` and a readable
	/// installed-state file, the same definition of an installed region the launcher uses.
	func reuseSession(for region: GameRegion, target: InstallerInstallDirectory) async
		-> ReuseSession
	{
		guard let reuseSourceDirectories else { return .none }
		let candidates = await reuseSourceDirectories(region)
		var targetStatus = stat()
		guard fstat(target.root.descriptor, &targetStatus) == 0 else { return .none }
		var seen = [InstallerFileIdentity(targetStatus)]
		var sources: [ReuseSource] = []
		for candidate in candidates where !Task.isCancelled {
			var status = stat()
			guard stat(candidate.path, &status) == 0, status.st_mode & S_IFMT == S_IFDIR else {
				continue
			}
			let identity = InstallerFileIdentity(status)
			guard !seen.contains(identity) else { continue }
			seen.append(identity)
			do {
				sources.append(try loadReuseSource(at: candidate))
			} catch {
				log?.debug(
					"Skipping \(candidate.path) as a reuse source: \(error.localizedDescription)"
				)
			}
		}
		return ReuseSession(sources: sources)
	}

	private func loadReuseSource(at directory: URL) throws -> ReuseSource {
		var executable = stat()
		guard stat(directory.appending(path: "Arknights.exe").path, &executable) == 0,
			executable.st_mode & S_IFMT == S_IFREG
		else { throw POSIXError(.ENOENT) }
		let data = try BoundedFileReader.readRegularFile(
			at: directory.appending(path: AppConstants.Game.installedStateFileName),
			maximumBytes: AppConstants.Game.installedStateMaximumBytes
		)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let state = try decoder.decode(InstalledState.self, from: data)
		return ReuseSource(
			directory: directory,
			knownPaths: state.files.map { Set($0.map(\.path)) }
		)
	}

	/// Tries to satisfy `item` from a donor region. Returns `true` once a donor's clone has
	/// passed the manifest checksum and been promoted exactly like a downloaded file; `false`
	/// means the caller must download. A failing donor never fails the installation.
	func reuseFromOtherRegions(
		_ item: ManifestFile,
		installDirectory: InstallerInstallDirectory,
		session: ReuseSession,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws -> Bool {
		guard !session.sources.isEmpty else { return false }
		try Task.checkCancellation()
		let relativePath = try Self.safeRelativePath(item.path)
		let destination = try installFile(
			at: relativePath, inside: installDirectory, createParents: true)
		let partial = destination.sibling(named: destination.name + ".part")
		try assertRegularDestinationIfPresent(destination)
		try assertSafeExistingPartialFile(at: partial)
		// Resumable bytes are worth more than a donor clone of unknown provenance.
		let partialSize = try fileSize(at: partial) ?? 0
		guard partialSize == 0 else { return false }
		let stagingDirectory: InstallerDirectoryHandle
		do {
			stagingDirectory = try installDirectory.stagingDirectory(
				named: AppConstants.Game.installerStagingDirectoryName
			)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
		for source in session.sources where source.mayContain(relativePath) {
			try Task.checkCancellation()
			do {
				guard
					try await adoptClone(
						of: item,
						relativePath: relativePath,
						from: source,
						partial: partial,
						destination: destination,
						stagingDirectory: stagingDirectory,
						counter: counter,
						progress: progress
					)
				else { continue }
				await session.tally.record(bytes: item.byteCount)
				removeEmptyPartial(partial)
				return true
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				log?.debug(
					"Could not reuse \(item.path) from \(source.directory.path); falling back: "
						+ launcherDiagnosticDescription(for: error)
				)
			}
		}
		return false
	}

	/// `CLONE_NOFOLLOW | CLONE_NOOWNCOPY` from `<sys/attr.h>`; the latter is not imported into
	/// Swift. The clone belongs to this user even when the donor file is owned by another.
	private static let cloneFlags: UInt32 = 0x0001 | 0x0002

	private func adoptClone(
		of item: ManifestFile,
		relativePath: String,
		from source: ReuseSource,
		partial: InstallerFilePath,
		destination: InstallerFilePath,
		stagingDirectory: InstallerDirectoryHandle,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws -> Bool {
		let sourceURL = source.directory.appending(path: relativePath)
		let sourceDescriptor = open(sourceURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
		guard sourceDescriptor >= 0 else {
			if errno == ENOENT { return false }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		defer { _ = close(sourceDescriptor) }
		var sourceStatus = stat()
		var siblingPart = stat()
		guard fstat(sourceDescriptor, &sourceStatus) == 0,
			sourceStatus.st_mode & S_IFMT == S_IFREG,
			Int64(sourceStatus.st_size) == item.byteCount,
			// A donor file with a sibling `.part` is mid-update and not a settled copy.
			stat(sourceURL.path + ".part", &siblingPart) != 0
		else { return false }

		let clone = stagingDirectory.file(named: "reuse-\(UUID().uuidString).tmp")
		guard
			fclonefileat(
				sourceDescriptor,
				stagingDirectory.descriptor,
				clone.name,
				Self.cloneFlags
			) == 0
		else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		defer {
			do {
				try clone.unlink()
			} catch {
				log?.error(
					"Failed to remove reuse clone at \(clone.url.path): \(error.localizedDescription)"
				)
			}
		}
		let cloneDescriptor = try clone.open(flags: O_RDWR | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(cloneDescriptor) }
		try InstallerInstallDirectory.makePrivateRegularFile(cloneDescriptor, at: clone.url)

		// The clone takes the place of a finished `.part`, so it gets the same size check,
		// checksum, atomic promotion, and failure handling as a download.
		try await finishDownload(
			item,
			partial: partial,
			partialDescriptor: cloneDescriptor,
			destination: destination,
			stagingDirectory: stagingDirectory,
			metadataFile: resumeMetadataFile(for: relativePath, in: stagingDirectory),
			countedBytes: 0,
			networkBytes: 0,
			counter: counter,
			progress: progress
		)
		await progress(await counter.addReused(bytes: item.byteCount, file: item.path))
		log?.debug("Reused \(item.path) (\(item.byteCount) bytes) from \(source.directory.path)")
		return true
	}

	private func removeEmptyPartial(_ partial: InstallerFilePath) {
		do {
			if let status = try partial.stat(), status.st_size == 0 { try partial.unlink() }
		} catch {
			log?.error(
				"Failed to remove empty partial at \(partial.url.path): \(error.localizedDescription)"
			)
		}
	}
}
