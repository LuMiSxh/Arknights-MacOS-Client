// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Failures raised while validating, downloading, and writing game files.
enum InstallerError: LocalizedError, LauncherDiagnosticError, Sendable {
	case invalidManifestPath(String)
	case duplicateManifestPath(String)
	case conflictingManifestPaths(String, String)
	case symbolicLinkInInstallPath(URL)
	case invalidDownloadResponse(status: Int, path: String)
	case downloadedSizeMismatch(path: String, expected: Int64, actual: Int64)
	case checksumMismatch(path: String, expected: String, actual: String)
	case cannotCreateFile(URL)
	case unsafeInstallerTemporaryFile(URL)
	case installDirectoryInUse(URL)
	case missingConfiguration
	case insufficientDiskSpace(required: Int64, available: Int64)

	/// Recovery guidance for alerts; paths, checksums, and status codes stay in diagnostics.
	var errorDescription: String? {
		switch self {
		case .invalidManifestPath, .duplicateManifestPath, .conflictingManifestPaths:
			"The game's file list contains unsafe or conflicting paths. Installation was stopped. Try again later."
		case .symbolicLinkInInstallPath:
			"The install folder contains a symbolic link. Choose a regular folder and try again."
		case .invalidDownloadResponse:
			"A game file could not be downloaded. Check your connection and try again."
		case .downloadedSizeMismatch, .checksumMismatch:
			"A downloaded file was damaged or incomplete. Try again to download the file again."
		case .cannotCreateFile:
			"The launcher could not create a file. Check folder permissions and free disk space, then try again."
		case .unsafeInstallerTemporaryFile:
			"The launcher could not safely write to the install folder. Choose another folder and try again."
		case .installDirectoryInUse:
			"Another launcher process is changing this install folder. Wait for it to finish and try again."
		case .missingConfiguration:
			"Game information has not loaded yet. Refresh the launcher and try again."
		case .insufficientDiskSpace(let required, let available):
			"Arknights needs about \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)) free, but only \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) is available. Free up space and try again."
		}
	}

	var diagnosticDescription: String {
		switch self {
		case .invalidManifestPath(let path): "Unsafe path in game manifest: \(path)"
		case .duplicateManifestPath(let path): "Duplicate path in game manifest: \(path)"
		case .conflictingManifestPaths(let parent, let child):
			"Conflicting paths in game manifest: \(parent) and \(child)"
		case .symbolicLinkInInstallPath(let url):
			"The game installer refused a symbolic link in its destination: \(url.path)"
		case .invalidDownloadResponse(let status, let path):
			"Download for \(path) returned HTTP \(status)."
		case .downloadedSizeMismatch(let path, let expected, let actual):
			"\(path) has \(actual) bytes instead of \(expected)."
		case .checksumMismatch(let path, let expected, let actual):
			"Checksum check for \(path) failed (\(actual), expected \(expected))."
		case .cannotCreateFile(let url): "Could not create temporary file: \(url.path)"
		case .unsafeInstallerTemporaryFile(let url):
			"The installer refused a non-regular or multiply linked temporary file: \(url.path)"
		case .installDirectoryInUse(let url):
			"Another launcher process holds the install lease for \(url.path)."
		case .missingConfiguration: "The current game configuration has not been loaded yet."
		case .insufficientDiskSpace:
			errorDescription ?? "The operation could not be completed."
		}
	}
}
