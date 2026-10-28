// SPDX-License-Identifier: MPL-2.0

import Foundation

package protocol LauncherDiagnosticError: LocalizedError {
	var diagnosticDescription: String { get }
}

/// Keeps alerts concise while carrying operation details into `launcher.log`.
package struct ContextualLauncherError: LocalizedError, LauncherDiagnosticError,
	SupportCodeProviding, Sendable
{
	let userMessage: String
	package let diagnosticDescription: String
	package let supportCode: SupportCode?

	package init(
		userMessage: String, diagnosticDescription: String, supportCode: SupportCode? = nil
	) {
		self.userMessage = userMessage
		self.diagnosticDescription = diagnosticDescription
		self.supportCode = supportCode
	}

	package var errorDescription: String? { userMessage }
}

package func launcherDiagnosticDescription(for error: any Error) -> String {
	(error as? any LauncherDiagnosticError)?.diagnosticDescription
		?? error.localizedDescription
}

package func launcherUserMessage(for error: any Error) -> String {
	if error is URLError {
		return "A network error occurred. Check your connection and try again."
	}
	if let description = (error as? any LauncherDiagnosticError)?.errorDescription {
		return description
	}
	return "The operation could not be completed because of an unexpected error."
}

extension LauncherError: SupportCodeProviding {
	package var supportCode: SupportCode? {
		if case .storageMigrationFailed = self { .dataMigrationFailed } else { nil }
	}
}

/// The diagnostics archive could not be saved. The user text names no path; the detail goes to the log.
package struct DiagnosticsError: LauncherDiagnosticError, SupportCodeProviding, Sendable {
	let detail: String

	package init(detail: String) {
		self.detail = detail
	}

	package var errorDescription: String? {
		"The diagnostics archive could not be saved. Check free disk space and the Downloads folder permissions, then try again."
	}

	package var diagnosticDescription: String { "Diagnostics archive failed: \(detail)" }
	package var supportCode: SupportCode? { .localFileFailed }
}

/// Failures shared by every feature; feature-specific failures live in their own error types.
package enum LauncherError: LocalizedError, LauncherDiagnosticError, Sendable {
	case invalidResponse
	case server(code: Int, message: String)
	case remoteContentTooLarge(URL, maximumBytes: Int)
	case storageMigrationFailed(String)

	/// Recovery guidance for alerts; paths, checksums, and status codes stay in diagnostics.
	package var errorDescription: String? {
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

	package var diagnosticDescription: String {
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
