// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

// Carries request diagnostics for failures that must keep their `LauncherError` meaning and
// support code.
struct DiagnosedLauncherError: LauncherDiagnosticError, Sendable {
	let underlying: LauncherError
	let diagnosticDescription: String

	var errorDescription: String? { underlying.errorDescription }
}

// Cancellation is never mapped, so callers keep their own cancellation handling.
struct LauncherHTTPClient: Sendable {
	enum Style: Sendable {
		case contextual
		case diagnosed
	}

	let apiName: String
	let style: Style
	let fetcher: CheckedHTTPFetcher

	func data(
		for request: URLRequest,
		maximumBytes: Int,
		operation: String,
		region: GameRegion,
		redirectValidator: @escaping @Sendable (URL) -> Bool
	) async throws -> (Data, HTTPURLResponse) {
		let url = request.url ?? region.apiBaseURL
		do {
			let result = try await fetcher.fetch(
				[request],
				policy: HTTPFetchPolicy(maximumBytes: maximumBytes),
				redirectValidator: redirectValidator
			)
			return (result.data, result.response)
		} catch let error as HTTPFetchError {
			guard case .unexpectedStatus(let status, _) = error else { throw error }
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				statusCode: status,
				reason: "unexpected HTTP status"
			)
		} catch let error as HTTPTransportError {
			switch error {
			case .redirectRejected(let rejectedURL):
				throw requestError(
					operation: operation,
					region: region,
					url: url,
					reason: "redirect refused unsupported origin " + (rejectedURL.host ?? "unknown")
				)
			case .responseTooLarge(let responseURL, let limit):
				throw requestError(
					operation: operation,
					region: region,
					url: url,
					reason: "response exceeded \(limit) bytes",
					underlying: .remoteContentTooLarge(responseURL, maximumBytes: limit)
				)
			case .responseSizeMismatch(_, let expected, let actual):
				throw requestError(
					operation: operation,
					region: region,
					url: url,
					reason: "response size was \(actual) bytes; expected \(expected)"
				)
			case .invalidResponse:
				throw requestError(
					operation: operation,
					region: region,
					url: url,
					reason: "response was not HTTP"
				)
			}
		} catch is CancellationError {
			throw CancellationError()
		} catch {
			// A diagnosed caller keeps `URLError`, whose alert and support code name the network.
			if style == .diagnosed { throw error }
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				reason: "transport error: \(error.localizedDescription)"
			)
		}
	}

	func requestError(
		operation: String,
		region: GameRegion,
		url: URL,
		statusCode: Int? = nil,
		reason: String,
		underlying: LauncherError = .invalidResponse
	) -> any Error {
		let endpoint = [url.host, url.path.isEmpty ? nil : url.path]
			.compactMap { $0 }
			.joined()
		let status = statusCode.map { " status=\($0)" } ?? ""
		let diagnostic =
			"\(apiName) API request failed; operation=\(operation); region=\(region.displayName); endpoint=\(endpoint);\(status) reason=\(reason)"
		switch style {
		case .contextual:
			return ContextualLauncherError(
				userMessage: underlying.localizedDescription,
				diagnosticDescription: diagnostic
			)
		case .diagnosed:
			return DiagnosedLauncherError(underlying: underlying, diagnosticDescription: diagnostic)
		}
	}
}
