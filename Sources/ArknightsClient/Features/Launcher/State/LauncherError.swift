// SPDX-License-Identifier: MPL-2.0

import Foundation

protocol LauncherDiagnosticError: LocalizedError {
	var diagnosticDescription: String { get }
}

/// Keeps alerts concise while carrying operation details into `launcher.log`.
struct ContextualLauncherError: LocalizedError, LauncherDiagnosticError, Sendable {
	let userMessage: String
	let diagnosticDescription: String

	var errorDescription: String? { userMessage }
}

func launcherDiagnosticDescription(for error: any Error) -> String {
	(error as? any LauncherDiagnosticError)?.diagnosticDescription
		?? error.localizedDescription
}

func launcherUserMessage(for error: any Error) -> String {
	if error is URLError {
		return L10n.string(.Launcher.launcherErrorNetwork)
	}
	if let description = (error as? any LauncherDiagnosticError)?.errorDescription {
		return description
	}
	return L10n.string(.Launcher.launcherErrorUnexpected)
}

enum LauncherError: LocalizedError, LauncherDiagnosticError {
	case invalidResponse
	case server(code: Int, message: String)
	case invalidManifestPath(String)
	case duplicateManifestPath(String)
	case conflictingManifestPaths(String, String)
	case symbolicLinkInInstallPath(URL)
	case invalidDownloadResponse(status: Int, path: String)
	case remoteContentTooLarge(URL, maximumBytes: Int)
	case invalidRemoteAsset(URL)
	case invalidPresetImage(URL)
	case invalidCustomImage(URL)
	case cannotEncodeAppIcon
	case cannotSetAppIcon
	case downloadedSizeMismatch(path: String, expected: Int64, actual: Int64)
	case checksumMismatch(path: String, expected: String, actual: String)
	case cannotCreateFile(URL)
	case unsafeInstallerTemporaryFile(URL)
	case missingConfiguration
	case gameNotInstalled(URL)
	case insufficientDiskSpace(required: Int64, available: Int64)
	case wineRuntimeMissing
	case rosettaMissing
	case rosettaDisabledByGameTestMode
	case intelTranslationUnavailable
	case intelTranslationUnsupported
	case runtimeWindowTimeout
	case runtimeConfiguration(String)
	case gameCompatibility(String)
	case runtimeExited(status: Int32, log: URL)

	var errorDescription: String? {
		switch self {
		case .invalidResponse:
			L10n.string(.Launcher.launcherErrorInvalidResponse)
		case .server(let code, let message):
			L10n.string(.Launcher.launcherErrorServer(String(code), message))
		case .invalidManifestPath(let path):
			L10n.string(.Launcher.launcherErrorInvalidManifestPath(path))
		case .duplicateManifestPath(let path):
			L10n.string(.Launcher.launcherErrorDuplicateManifestPath(path))
		case .conflictingManifestPaths(let parent, let child):
			L10n.string(.Launcher.launcherErrorConflictingManifestPaths(parent, child))
		case .symbolicLinkInInstallPath(let url):
			L10n.string(.Launcher.launcherErrorSymbolicLink(url.path))
		case .invalidDownloadResponse(let status, let path):
			L10n.string(.Launcher.launcherErrorDownloadResponse(path, String(status)))
		case .remoteContentTooLarge(let url, let maximumBytes):
			L10n.string(
				.Launcher.launcherErrorRemoteContentTooLarge(
					url.host ?? url.absoluteString,
					ByteCountFormatter.string(fromByteCount: Int64(maximumBytes), countStyle: .file)
				))
		case .invalidRemoteAsset(let url):
			L10n.string(.Launcher.launcherErrorInvalidRemoteAsset(url.absoluteString))
		case .invalidPresetImage(let url):
			L10n.string(.Launcher.launcherErrorInvalidPresetImage(url.absoluteString))
		case .invalidCustomImage(let url):
			L10n.string(.Launcher.launcherErrorInvalidCustomImage(url.path))
		case .cannotEncodeAppIcon:
			L10n.string(.Launcher.launcherErrorCannotEncodeAppIcon)
		case .cannotSetAppIcon:
			L10n.string(.Launcher.launcherErrorCannotSetAppIcon)
		case .downloadedSizeMismatch(let path, let expected, let actual):
			L10n.string(
				.Launcher.launcherErrorDownloadedSizeMismatch(
					path, String(actual), String(expected))
			)
		case .checksumMismatch(let path, let expected, let actual):
			L10n.string(.Launcher.launcherErrorChecksumMismatch(path, actual, expected))
		case .cannotCreateFile(let url):
			L10n.string(.Launcher.launcherErrorCannotCreateFile(url.path))
		case .unsafeInstallerTemporaryFile(let url):
			L10n.string(.Launcher.launcherErrorUnsafeTemporaryFile(url.path))
		case .missingConfiguration:
			L10n.string(.Launcher.launcherErrorMissingConfiguration)
		case .gameNotInstalled(let url):
			L10n.string(.Launcher.launcherErrorGameNotInstalled(url.path))
		case .insufficientDiskSpace(let required, let available):
			L10n.string(
				.Launcher.launcherErrorInsufficientDiskSpace(
					ByteCountFormatter.string(fromByteCount: required, countStyle: .file),
					ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
				))
		case .wineRuntimeMissing:
			L10n.string(.Launcher.launcherErrorWineRuntimeMissing)
		case .rosettaMissing:
			L10n.string(.Launcher.launcherErrorRosettaMissing)
		case .rosettaDisabledByGameTestMode:
			L10n.string(.Launcher.launcherErrorRosettaDisabled)
		case .intelTranslationUnavailable:
			L10n.string(.Launcher.launcherErrorIntelTranslationUnavailable)
		case .intelTranslationUnsupported:
			L10n.string(.Launcher.launcherErrorIntelTranslationUnsupported)
		case .runtimeWindowTimeout:
			L10n.string(.Launcher.launcherErrorRuntimeWindowTimeout)
		case .runtimeConfiguration(let message):
			L10n.string(.Launcher.launcherErrorRuntimeConfiguration(message))
		case .gameCompatibility:
			L10n.string(.Launcher.launcherErrorGameCompatibility)
		case .runtimeExited(let status, let log):
			L10n.string(.Launcher.launcherErrorRuntimeExited(String(status), log.path))
		}
	}

	var diagnosticDescription: String {
		switch self {
		case .invalidResponse: "The game service returned an invalid response."
		case .server(let code, let message): "Yostar API error \(code): \(message)"
		case .invalidManifestPath(let path): "Unsafe path in game manifest: \(path)"
		case .duplicateManifestPath(let path): "Duplicate path in game manifest: \(path)"
		case .conflictingManifestPaths(let parent, let child):
			"Conflicting paths in game manifest: \(parent) and \(child)"
		case .symbolicLinkInInstallPath(let url):
			"The game installer refused a symbolic link in its destination: \(url.path)"
		case .invalidDownloadResponse(let status, let path):
			"Download for \(path) returned HTTP \(status)."
		case .remoteContentTooLarge(let url, let maximumBytes):
			"Remote content from \(url.host ?? url.absoluteString) exceeded the \(ByteCountFormatter.string(fromByteCount: Int64(maximumBytes), countStyle: .file)) limit."
		case .invalidRemoteAsset(let url):
			"Refused an unsupported remote asset URL: \(url.absoluteString)"
		case .invalidPresetImage(let url):
			"The preset asset is not a supported image or has unsafe dimensions: \(url.absoluteString)"
		case .invalidCustomImage(let url): "The selected file is not a supported image: \(url.path)"
		case .cannotEncodeAppIcon: "The selected image could not be converted into an app icon."
		case .cannotSetAppIcon: "macOS refused to update the app icon."
		case .downloadedSizeMismatch(let path, let expected, let actual):
			"\(path) has \(actual) bytes instead of \(expected)."
		case .checksumMismatch(let path, let expected, let actual):
			"CRC64 check for \(path) failed (\(actual), expected \(expected))."
		case .cannotCreateFile(let url): "Could not create temporary file: \(url.path)"
		case .unsafeInstallerTemporaryFile(let url):
			"The installer refused a non-regular or multiply linked temporary file: \(url.path)"
		case .missingConfiguration: "The current game configuration has not been loaded yet."
		case .gameNotInstalled(let url): "Arknights.exe was not found: \(url.path)"
		case .insufficientDiskSpace(let required, let available):
			"Arknights needs about \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)) free, but only \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) is available. Free up space and try again."
		case .wineRuntimeMissing:
			"No compatible Windows runtime found. Use a build that bundles Wine + DXMT."
		case .rosettaMissing:
			"Rosetta 2 is required to run the bundled Wine runtime. Install it by running \"softwareupdate --install-rosetta --agree-to-license\" in Terminal, then check again."
		case .rosettaDisabledByGameTestMode:
			"macOS Legacy Game Test Mode disables the Rosetta translation required by Wine. Run \"sudo game-test-tool disable\" in Terminal, restart your Mac, then check again."
		case .intelTranslationUnavailable:
			"macOS could not start the Intel-based Wine runtime. Check that Rosetta 2 is installed and restart your Mac before trying again."
		case .intelTranslationUnsupported:
			"This macOS version no longer supports the general Intel translation required by the bundled Wine runtime."
		case .runtimeWindowTimeout:
			"Arknights did not open a window within 90 seconds. Check the Wine log and try again."
		case .runtimeConfiguration(let message):
			"The Windows runtime could not be configured: \(message)"
		case .gameCompatibility(let message):
			"Game compatibility setup could not be completed: \(message)"
		case .runtimeExited(let status, let log):
			"The Windows runtime exited with status \(status). See \(log.path)."
		}
	}
}
