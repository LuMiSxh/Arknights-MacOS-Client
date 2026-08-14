// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherPhase: Equatable, Sendable {
	case checking
	case ready
	case downloading
	case launching
	case running(processIdentifier: Int32)
	case failed(String)

	var title: String {
		switch self {
		case .checking: "Checking version"
		case .ready: "Ready"
		case .downloading: "Downloading game files"
		case .launching: "Starting Windows runtime"
		case .running: "Game started"
		case .failed: "Action failed"
		}
	}
}

enum LauncherError: LocalizedError {
	case invalidResponse
	case server(code: Int, message: String)
	case invalidManifestPath(String)
	case invalidDownloadResponse(status: Int, path: String)
	case downloadedSizeMismatch(path: String, expected: Int64, actual: Int64)
	case checksumMismatch(path: String, expected: String, actual: String)
	case cannotCreateFile(URL)
	case missingConfiguration
	case gameNotInstalled(URL)
	case wineRuntimeMissing
	case runtimeConfiguration(String)
	case runtimeExited(status: Int32, log: URL)

	var errorDescription: String? {
		switch self {
		case .invalidResponse:
			"Yostar's server returned an invalid response."
		case .server(let code, let message):
			"Yostar API error \(code): \(message)"
		case .invalidManifestPath(let path):
			"Unsafe path in game manifest: \(path)"
		case .invalidDownloadResponse(let status, let path):
			"Download for \(path) returned HTTP \(status)."
		case .downloadedSizeMismatch(let path, let expected, let actual):
			"\(path) has \(actual) bytes instead of \(expected)."
		case .checksumMismatch(let path, let expected, let actual):
			"CRC64 check for \(path) failed (\(actual), expected \(expected))."
		case .cannotCreateFile(let url):
			"Could not create temporary file: \(url.path)"
		case .missingConfiguration:
			"The current game configuration has not been loaded yet."
		case .gameNotInstalled(let url):
			"Arknights.exe was not found: \(url.path)"
		case .wineRuntimeMissing:
			"No compatible Windows runtime found. Use a build that bundles Wine + DXMT."
		case .runtimeConfiguration(let message):
			"The Windows runtime could not be configured: \(message)"
		case .runtimeExited(let status, let log):
			"The Windows runtime exited with status \(status). See \(log.path)."
		}
	}
}
