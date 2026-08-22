// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation

/// Talks to Yostar's launcher API using the same version, salt, and MD5 signature scheme
/// their own official launcher sends; requests that don't match are rejected server-side.
actor LauncherAPI {
	// The version and salt Yostar's own official launcher sends; this API rejects requests
	// that don't sign with them, so this is not this app's own version (see
	// Bundle.shortVersionString for that) and must not be bumped independently.
	static let launcherVersion = "1.8.1"

	private let salt = "DE7108E9B2842FD460F4777702727869"
	private let session: URLSession
	private let decoder: JSONDecoder

	init(session: URLSession = .shared) {
		self.session = session
		decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
	}

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		try await request(
			region: region,
			path: "/api/launcher/game/config",
			operation: "game configuration"
		)
	}

	func branding(region: GameRegion) async throws -> LauncherBranding {
		try await request(
			region: region,
			path: "/api/launcher/base/config",
			operation: "launcher branding"
		)
	}

	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration {
		try await request(
			region: region,
			path: "/api/launcher/advanced/game/download/cdn",
			operation: "CDN configuration"
		)
	}

	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest {
		var components = URLComponents(
			url: region.apiBaseURL.appending(path: "/api/launcher/game/config/json"),
			resolvingAgainstBaseURL: false
		)
		components?.queryItems = [
			URLQueryItem(name: "version", value: configuration.gameLatestVersion),
			URLQueryItem(name: "file_path", value: configuration.gameLatestFilePath),
		]
		guard let locationURL = components?.url else {
			throw requestError(
				operation: "manifest location",
				region: region,
				url: region.apiBaseURL,
				reason: "could not construct the request URL"
			)
		}
		let location: ManifestLocation = try await request(
			region: region,
			url: locationURL,
			operation: "manifest location"
		)

		var manifestRequest = URLRequest(url: location.url)
		manifestRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: manifestRequest)
		} catch is CancellationError {
			throw CancellationError()
		} catch {
			throw requestError(
				operation: "manifest download",
				region: region,
				url: location.url,
				reason: "transport error: \(error.localizedDescription)",
				userMessage: error.localizedDescription
			)
		}
		guard let http = response as? HTTPURLResponse else {
			throw requestError(
				operation: "manifest download",
				region: region,
				url: location.url,
				reason: "response was not HTTP"
			)
		}
		guard http.statusCode == 200 else {
			throw requestError(
				operation: "manifest download",
				region: region,
				url: location.url,
				statusCode: http.statusCode,
				reason: "unexpected HTTP status"
			)
		}
		do {
			return try decoder.decode(GameManifest.self, from: data)
		} catch {
			throw requestError(
				operation: "manifest download",
				region: region,
				url: location.url,
				statusCode: http.statusCode,
				reason: "decoding failed: \(error.localizedDescription)"
			)
		}
	}

	func authorizationHeader(
		region: GameRegion,
		timestamp: Int64 = Int64(Date().timeIntervalSince1970)
	) -> String {
		let head =
			"{\"game_tag\":\"\(region.gameTag)\",\"time\":\(timestamp),\"version\":\"\(Self.launcherVersion)\"}"
		let digest = Insecure.MD5.hash(data: Data("\(head)\(salt)".utf8))
		let signature = digest.map { String(format: "%02x", $0) }.joined()
		return "{\"head\":\(head),\"sign\":\"\(signature)\"}"
	}

	private func request<Value: Decodable>(
		region: GameRegion,
		path: String,
		operation: String
	) async throws -> Value {
		try await request(
			region: region,
			url: region.apiBaseURL.appending(path: path),
			operation: operation
		)
	}

	private func request<Value: Decodable>(
		region: GameRegion,
		url: URL,
		operation: String
	) async throws -> Value {
		var request = URLRequest(url: url)
		request.setValue(authorizationHeader(region: region), forHTTPHeaderField: "Authorization")
		request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: request)
		} catch is CancellationError {
			throw CancellationError()
		} catch {
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				reason: "transport error: \(error.localizedDescription)",
				userMessage: error.localizedDescription
			)
		}
		guard let http = response as? HTTPURLResponse else {
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				reason: "response was not HTTP"
			)
		}
		guard http.statusCode == 200 else {
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				statusCode: http.statusCode,
				reason: "unexpected HTTP status"
			)
		}
		let envelope: APIEnvelope<Value>
		do {
			envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
		} catch {
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				statusCode: http.statusCode,
				reason: "decoding failed: \(error.localizedDescription)"
			)
		}
		guard envelope.code == 200 else {
			let serverError = LauncherError.server(
				code: envelope.code,
				message: envelope.msg ?? "Unknown error"
			)
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				statusCode: http.statusCode,
				reason: "API envelope code \(envelope.code): \(envelope.msg ?? "Unknown error")",
				userMessage: serverError.localizedDescription
			)
		}
		return envelope.data
	}

	private func requestError(
		operation: String,
		region: GameRegion,
		url: URL,
		statusCode: Int? = nil,
		reason: String,
		userMessage: String = LauncherError.invalidResponse.localizedDescription
	) -> ContextualLauncherError {
		let endpoint = [url.host, url.path.isEmpty ? nil : url.path]
			.compactMap { $0 }
			.joined()
		let status = statusCode.map { " status=\($0)" } ?? ""
		return ContextualLauncherError(
			userMessage: userMessage,
			diagnosticDescription:
				"Yostar API request failed; operation=\(operation); region=\(region.displayName); endpoint=\(endpoint);\(status) reason=\(reason)"
		)
	}
}
