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
		try await request(region: region, path: "/api/launcher/game/config")
	}

	func branding(region: GameRegion) async throws -> LauncherBranding {
		try await request(region: region, path: "/api/launcher/base/config")
	}

	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration {
		try await request(region: region, path: "/api/launcher/advanced/game/download/cdn")
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
			throw LauncherError.invalidResponse
		}
		let location: ManifestLocation = try await request(region: region, url: locationURL)

		var manifestRequest = URLRequest(url: location.url)
		manifestRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		let (data, response) = try await session.data(for: manifestRequest)
		guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
			throw LauncherError.invalidResponse
		}
		return try decoder.decode(GameManifest.self, from: data)
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

	private func request<Value: Decodable>(region: GameRegion, path: String) async throws -> Value {
		try await request(region: region, url: region.apiBaseURL.appending(path: path))
	}

	private func request<Value: Decodable>(region: GameRegion, url: URL) async throws -> Value {
		var request = URLRequest(url: url)
		request.setValue(authorizationHeader(region: region), forHTTPHeaderField: "Authorization")
		request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
		let (data, response) = try await session.data(for: request)
		guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
			throw LauncherError.invalidResponse
		}
		let envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
		guard envelope.code == 200 else {
			throw LauncherError.server(
				code: envelope.code, message: envelope.msg ?? "Unknown error")
		}
		return envelope.data
	}
}
