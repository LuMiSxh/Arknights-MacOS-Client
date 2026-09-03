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
	private let loader: BoundedHTTPDataLoader
	private let decoder: JSONDecoder
	private let maximumAPIResponseBytes: Int
	private let maximumManifestResponseBytes: Int
	private let hypergryph: HypergryphLauncherAPI

	init(
		session: URLSession = .shared,
		maximumAPIResponseBytes: Int = AppConstants.Network.yostarAPIResponseMaximumBytes,
		maximumManifestResponseBytes: Int = AppConstants.Network.yostarManifestMaximumBytes
	) {
		loader = BoundedHTTPDataLoader(session: session)
		self.maximumAPIResponseBytes = maximumAPIResponseBytes
		self.maximumManifestResponseBytes = maximumManifestResponseBytes
		hypergryph = HypergryphLauncherAPI(
			session: session,
			maximumAPIResponseBytes: maximumAPIResponseBytes,
			maximumManifestResponseBytes: maximumManifestResponseBytes
		)
		decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
	}

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		if let channel = region.hypergryphChannel {
			return try await hypergryph.gameConfiguration(channel: channel)
		}
		return try await request(
			region: region,
			path: "/api/launcher/game/config",
			operation: "game configuration"
		)
	}

	func branding(region: GameRegion) async throws -> LauncherBranding {
		if let channel = region.hypergryphChannel {
			return try await hypergryph.branding(channel: channel)
		}
		return try await request(
			region: region,
			path: "/api/launcher/base/config",
			operation: "launcher branding"
		)
	}

	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration {
		if let channel = region.hypergryphChannel {
			return try await hypergryph.cdnConfiguration(channel: channel)
		}
		return try await request(
			region: region,
			path: "/api/launcher/advanced/game/download/cdn",
			operation: "CDN configuration"
		)
	}

	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest {
		if region.hypergryphChannel != nil {
			return try await hypergryph.manifest(for: configuration)
		}
		let location = try await manifestLocation(for: configuration, region: region)
		return try await manifestPayload(at: location.url, region: region).manifest
	}

	func manifestLocation(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> ManifestLocation {
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
		return location
	}

	func manifestPayload(
		at url: URL,
		region: GameRegion
	) async throws -> (manifest: GameManifest, byteCount: Int) {
		var manifestRequest = URLRequest(url: url)
		manifestRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		let (data, response) = try await responseData(
			for: manifestRequest,
			maximumBytes: maximumManifestResponseBytes,
			operation: "manifest download",
			region: region,
			url: url
		)
		guard response.statusCode == 200 else {
			throw requestError(
				operation: "manifest download",
				region: region,
				url: url,
				statusCode: response.statusCode,
				reason: "unexpected HTTP status"
			)
		}
		do {
			return (try decoder.decode(GameManifest.self, from: data), data.count)
		} catch {
			throw requestError(
				operation: "manifest download",
				region: region,
				url: url,
				statusCode: response.statusCode,
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
		let (data, response) = try await responseData(
			for: request,
			maximumBytes: maximumAPIResponseBytes,
			operation: operation,
			region: region,
			url: url
		)
		guard response.statusCode == 200 else {
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				statusCode: response.statusCode,
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
				statusCode: response.statusCode,
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
				statusCode: response.statusCode,
				reason: "API envelope code \(envelope.code): \(envelope.msg ?? "Unknown error")",
				userMessage: serverError.localizedDescription
			)
		}
		return envelope.data
	}

	private func responseData(
		for request: URLRequest,
		maximumBytes: Int,
		operation: String,
		region: GameRegion,
		url: URL
	) async throws -> (Data, HTTPURLResponse) {
		do {
			return try await loader.data(for: request, maximumBytes: maximumBytes)
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as HTTPTransportError {
			if Task.isCancelled { throw CancellationError() }
			switch error {
			case .redirectRejected(let rejectedURL):
				throw requestError(
					operation: operation,
					region: region,
					url: url,
					reason: "redirect refused unsupported origin "
						+ (rejectedURL.host ?? "unknown"),
					userMessage: LauncherError.invalidResponse.localizedDescription
				)
			case .responseTooLarge(let responseURL, let limit):
				throw requestError(
					operation: operation,
					region: region,
					url: url,
					reason: "response exceeded \(limit) bytes",
					userMessage: LauncherError.remoteContentTooLarge(
						responseURL, maximumBytes: limit
					).localizedDescription
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
		} catch {
			throw requestError(
				operation: operation,
				region: region,
				url: url,
				reason: "transport error: \(error.localizedDescription)"
			)
		}
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
