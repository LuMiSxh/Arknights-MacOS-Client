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
		return "A network error occurred. Check your connection and try again."
	}
	if let description = (error as? any LauncherDiagnosticError)?.errorDescription {
		return description
	}
	return "The operation could not be completed because of an unexpected error."
}

extension LauncherError: SupportCodeProviding {
	var supportCode: SupportCode? {
		if case .storageMigrationFailed = self { .basalt } else { nil }
	}
}

/// Failures shared by every feature; feature-specific failures live in their own error types.
enum LauncherError: LocalizedError, LauncherDiagnosticError, Sendable {
	case invalidResponse
	case server(code: Int, message: String)
	case remoteContentTooLarge(URL, maximumBytes: Int)
	case storageMigrationFailed(String)

	/// Recovery guidance for alerts; paths, checksums, and status codes stay in diagnostics.
	var errorDescription: String? {
		switch self {
		case .invalidResponse:
			"The game service returned an unexpected response. Try again later."
		case .server:
			"The game service reported an error. Try again later."
		case .remoteContentTooLarge:
			"The requested content exceeds the launcher's size limit and cannot be used. Check for a launcher update and try again."
		case .storageMigrationFailed:
			"Launcher data could not be updated. Check the logs and try again."
		}
	}

	var diagnosticDescription: String {
		switch self {
		case .invalidResponse: "The game service returned an invalid response."
		case .server(let code, let message): "Game service API error \(code): \(message)"
		case .remoteContentTooLarge(let url, let maximumBytes):
			"Remote content from \(url.host ?? url.absoluteString) exceeded the \(ByteCountFormatter.string(fromByteCount: Int64(maximumBytes), countStyle: .file)) limit."
		case .storageMigrationFailed(let diagnostic):
			"Application storage migration failed: \(diagnostic)"
		}
	}
}
