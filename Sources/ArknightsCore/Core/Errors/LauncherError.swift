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

/// The stable identifier and optional detail written to a structured log line for `error`.
package func logFields(for error: any Error) -> (id: String, detail: String?) {
	(id: logIdentifier(for: error), detail: logDetail(for: error))
}

private func logIdentifier(for error: any Error) -> String {
	if let code = (error as? any SupportCodeProviding)?.supportCode {
		return code.rawValue
	}
	if let urlError = error as? URLError {
		return "URLError#\(urlError.code.rawValue)"
	}
	let nsError = error as NSError
	guard isSwiftNative(error) else {
		return "\(nsError.domain)#\(nsError.code)"
	}
	let typeName = String(describing: type(of: error))
	let caseName = String(describing: error)
		.split(separator: "(", maxSplits: 1, omittingEmptySubsequences: false)[0]
		.trimmingCharacters(in: .whitespaces)
	return "\(typeName).\(caseName)"
}

private func logDetail(for error: any Error) -> String? {
	if let diagnostic = (error as? any LauncherDiagnosticError)?.diagnosticDescription {
		return diagnostic
	}
	if let description = (error as? any LocalizedError)?.errorDescription {
		return description
	}
	// A Swift error without its own description bridges to the generic, system-localized
	// "operation couldn't be completed" text, which only repeats the identifier.
	return isSwiftNative(error) ? nil : error.localizedDescription
}

private func isSwiftNative(_ error: any Error) -> Bool {
	(error as NSError).domain == String(reflecting: type(of: error))
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
			"Remote content from \(url.host ?? url.logValue) exceeded the \(maximumBytes.formatted(.byteCount(style: .file))) limit."
		case .storageMigrationFailed(let diagnostic):
			"Application storage migration failed: \(diagnostic)"
		}
	}
}
