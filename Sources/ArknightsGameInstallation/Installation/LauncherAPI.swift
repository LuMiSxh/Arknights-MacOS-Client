// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsInfrastructure
import CryptoKit
import Foundation

/// Talks to Yostar's launcher API using the same version, salt, and MD5 signature scheme
/// their own official launcher sends; requests that don't match are rejected server-side.
package actor LauncherAPI {
	// The version and salt Yostar's own official launcher sends; this API rejects requests
	// that don't sign with them, so this is not this app's own version (see
	// Bundle.shortVersionString for that) and must not be bumped independently.
	static let launcherVersion = "1.8.1"

	private let salt = "DE7108E9B2842FD460F4777702727869"
	private let client: LauncherHTTPClient
	private let decoder: JSONDecoder
	private let maximumAPIResponseBytes: Int
	private let maximumManifestResponseBytes: Int
	private let hypergryph: HypergryphLauncherAPI

	package init(
		session: URLSession = .shared,
		maximumAPIResponseBytes: Int = AppConstants.Network.yostarAPIResponseMaximumBytes,
		maximumManifestResponseBytes: Int = AppConstants.Network.yostarManifestMaximumBytes
	) {
		client = LauncherHTTPClient(
			apiName: "Yostar",
			style: .contextual,
			fetcher: CheckedHTTPFetcher(
				loader: BoundedHTTPDataLoader(
					session: session,
					maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
				)
			)
		)
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

	package func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		if let profile = region.hypergryphProfile {
			return try await hypergryph.gameConfiguration(for: profile)
		}
		return try await request(
			region: region,
			path: "/api/launcher/game/config",
			operation: "game configuration"
		)
	}

	package func branding(region: GameRegion) async throws -> LauncherBranding {
		if let profile = region.hypergryphProfile {
			return try await hypergryph.branding(for: profile)
		}
		return try await request(
			region: region,
			path: "/api/launcher/base/config",
			operation: "launcher branding"
		)
	}

	package func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration {
		if let profile = region.hypergryphProfile {
			return try await hypergryph.cdnConfiguration(for: profile)
		}
		return try await request(
			region: region,
			path: "/api/launcher/advanced/game/download/cdn",
			operation: "CDN configuration"
		)
	}

	package func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest {
		if let profile = region.hypergryphProfile {
			return try await hypergryph.manifest(for: configuration, profile: profile)
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
			throw client.requestError(
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
		let (data, response) = try await client.data(
			for: manifestRequest,
			maximumBytes: maximumManifestResponseBytes,
			operation: "manifest download",
			region: region,
			redirectValidator: DownloadHTTPPolicy.redirectValidator(for: region)
		)
		do {
			return (try decoder.decode(GameManifest.self, from: data), data.count)
		} catch {
			throw client.requestError(
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
		let signature = digest.hexString
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
		let (data, response) = try await client.data(
			for: request,
			maximumBytes: maximumAPIResponseBytes,
			operation: operation,
			region: region,
			redirectValidator: DownloadHTTPPolicy.redirectValidator(for: region)
		)
		let envelope: APIEnvelope<Value>
		do {
			envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
		} catch {
			throw client.requestError(
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
			throw client.requestError(
				operation: operation,
				region: region,
				url: url,
				statusCode: response.statusCode,
				reason: "API envelope code \(envelope.code): \(envelope.msg ?? "Unknown error")",
				underlying: serverError
			)
		}
		return envelope.data
	}
}
