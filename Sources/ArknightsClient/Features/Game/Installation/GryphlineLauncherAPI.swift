// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Reads the traditional-Chinese Windows client contract exposed by Gryphline's launcher.
/// The adapter consumes metadata and the encrypted per-file manifest; it never runs the vendor
/// launcher.
actor GryphlineLauncherAPI {
	private static let metadataURL = URL(
		string: "https://launcher.gryphline.com/api/proxy/batch_proxy"
	)!
	private static let webMetadataURL = URL(
		string: "https://launcher.gryphline.com/api/proxy/web/batch_proxy"
	)!
	private static let launcherAppCode = "TiaytKBUIEdoEwRT"
	private static let gameAppCode = "uiCaUeGDB2htwXSv"
	private static let channel = "6"
	private static let subChannel = "6"
	private static let sequence = "5"
	private static let allowedAssetHosts: Set<String> = [
		"launcher.hg-cdn.com",
		"ak-tw.hg-cdn.com",
		"gl-utils-public.hg-cdn.com",
	]
	private static let allowedHosts = allowedAssetHosts.union(["launcher.gryphline.com"])

	private let loader: BoundedHTTPDataLoader
	private let maximumAPIResponseBytes: Int
	private let maximumManifestResponseBytes: Int
	private var latestPackage: GryphlinePackage?

	init(
		session: URLSession = .shared,
		maximumAPIResponseBytes: Int = AppConstants.Network.yostarAPIResponseMaximumBytes,
		maximumManifestResponseBytes: Int = AppConstants.Network.yostarManifestMaximumBytes
	) {
		loader = BoundedHTTPDataLoader(session: session) { url in
			guard url.scheme?.lowercased() == "https",
				url.user == nil,
				url.password == nil,
				url.port == nil,
				let host = url.host?.lowercased()
			else { return false }
			return Self.allowedHosts.contains(host)
		}
		self.maximumAPIResponseBytes = maximumAPIResponseBytes
		self.maximumManifestResponseBytes = maximumManifestResponseBytes
	}

	func gameConfiguration() async throws -> GameConfiguration {
		let latest = try await latestGame()
		latestPackage = latest.package
		guard let totalBytes = Int64(latest.package.totalSize), totalBytes >= 0 else {
			throw LauncherError.invalidResponse
		}
		let megabytes = totalBytes / 1_000_000 + (totalBytes % 1_000_000 == 0 ? 0 : 1)
		return GameConfiguration(
			gameLowestVersion: latest.version,
			gameLatestVersion: latest.version,
			gameLatestFilePath: latest.package.filePath.absoluteString,
			gameStartExeName: "Arknights.exe",
			gameStartParams: [],
			gameUninstallScript: "",
			decompressionSize: "\(megabytes)MB"
		)
	}

	func branding() async throws -> LauncherBranding {
		let payload = GryphlineBatchRequest(
			sequence: Self.sequence,
			requests: [
				GryphlineProxyRequest(
					kind: "get_main_bg_image",
					latestGame: nil,
					mainBackground: GryphlineCommonRequest(
						appCode: Self.gameAppCode,
						channel: Self.channel,
						subChannel: Self.subChannel,
						language: "zh-tw"
					)
				)
			]
		)
		let envelope = try await response(for: payload, at: Self.webMetadataURL)
		guard
			let image = envelope.responses.first(where: { $0.kind == "get_main_bg_image" })?
				.mainBackground?.image,
			Self.isTrustedAssetURL(image.url),
			image.md5.isEmpty
				|| (image.md5.count == 32 && image.md5.allSatisfy(\.isHexDigit))
		else { throw LauncherError.invalidResponse }
		return LauncherBranding(
			launcherBackgroundImage: image.url,
			launcherBackgroundImageCRC64: image.md5.isEmpty ? nil : image.md5,
			copyrightInformation: nil,
			privacyPolicy: nil,
			userAgreement: nil,
			noticePopOpen: false,
			noticeContent: nil
		)
	}

	func cdnConfiguration() async throws -> CDNConfiguration {
		let package = try await package()
		let baseURL = try Self.cdnOrigin(for: package.filePath)
		return CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
	}

	func manifest(for configuration: GameConfiguration) async throws -> GameManifest {
		guard let fileBaseURL = URL(string: configuration.gameLatestFilePath) else {
			throw LauncherError.invalidResponse
		}
		let source = try Self.cdnSource(for: fileBaseURL)
		let manifestURL = fileBaseURL.appending(path: "game_files")
		var request = URLRequest(url: manifestURL)
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		let (encrypted, response) = try await loader.data(
			for: request,
			maximumBytes: maximumManifestResponseBytes
		)
		guard response.statusCode == 200 else { throw LauncherError.invalidResponse }
		let decrypted = try HypergryphManifestCipher.decrypt(encrypted)
		guard let text = String(data: decrypted, encoding: .utf8) else {
			throw LauncherError.invalidResponse
		}
		let decoder = JSONDecoder()
		let files = try text.split(whereSeparator: \.isNewline).map { line in
			let entry = try decoder.decode(
				GryphlineManifestEntry.self,
				from: Data(line.utf8)
			)
			guard
				entry.size >= 0,
				entry.md5.count == 32,
				entry.md5.allSatisfy(\.isHexDigit)
			else { throw LauncherError.invalidResponse }
			return ManifestFile(path: entry.path, hash: entry.md5, size: String(entry.size))
		}
		guard !files.isEmpty else { throw LauncherError.invalidResponse }
		return GameManifest(source: source, file: files)
	}

	private func package() async throws -> GryphlinePackage {
		if let latestPackage { return latestPackage }
		let latest = try await latestGame()
		latestPackage = latest.package
		return latest.package
	}

	private func latestGame() async throws -> GryphlineLatestGame {
		let payload = GryphlineBatchRequest(
			sequence: Self.sequence,
			requests: [
				GryphlineProxyRequest(
					kind: "get_latest_game",
					latestGame: GryphlineLatestGameRequest(
						appCode: Self.gameAppCode,
						channel: Self.channel,
						subChannel: Self.subChannel,
						version: "",
						launcherAppCode: Self.launcherAppCode
					),
					mainBackground: nil
				)
			]
		)
		let envelope = try await response(for: payload, at: Self.metadataURL)
		guard
			let latest = envelope.responses.first(where: { $0.kind == "get_latest_game" })?
				.latestGame,
			!latest.version.isEmpty
		else { throw LauncherError.invalidResponse }
		_ = try Self.cdnOrigin(for: latest.package.filePath)
		return latest
	}

	private func response(
		for payload: GryphlineBatchRequest,
		at url: URL
	) async throws -> GryphlineBatchResponse {
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(payload)
		let (data, response) = try await loader.data(
			for: request,
			maximumBytes: maximumAPIResponseBytes
		)
		guard response.statusCode == 200 else { throw LauncherError.invalidResponse }
		return try JSONDecoder().decode(GryphlineBatchResponse.self, from: data)
	}

	private static func isTrustedAssetURL(_ url: URL) -> Bool {
		isTrustedURL(url) && url.host.map { allowedAssetHosts.contains($0.lowercased()) } == true
	}

	private static func isTrustedURL(_ url: URL) -> Bool {
		url.scheme?.lowercased() == "https"
			&& url.user == nil
			&& url.password == nil
			&& url.port == nil
	}

	private static func cdnOrigin(for url: URL) throws -> URL {
		guard
			isTrustedURL(url),
			let host = url.host?.lowercased(),
			allowedAssetHosts.contains(host),
			url.query == nil,
			url.fragment == nil
		else { throw LauncherError.invalidResponse }
		var components = URLComponents()
		components.scheme = "https"
		components.host = host
		guard let origin = components.url else { throw LauncherError.invalidResponse }
		return origin
	}

	private static func cdnSource(for url: URL) throws -> String {
		_ = try cdnOrigin(for: url)
		return try GameInstaller.safeRelativePath(url.path)
	}
}

private struct GryphlineBatchRequest: Encodable {
	let sequence: String
	let requests: [GryphlineProxyRequest]

	private enum CodingKeys: String, CodingKey {
		case sequence = "seq"
		case requests = "proxy_reqs"
	}
}

private struct GryphlineProxyRequest: Encodable {
	let kind: String
	let latestGame: GryphlineLatestGameRequest?
	let mainBackground: GryphlineCommonRequest?

	private enum CodingKeys: String, CodingKey {
		case kind
		case latestGame = "get_latest_game_req"
		case mainBackground = "get_main_bg_image_req"
	}
}

private struct GryphlineCommonRequest: Encodable {
	let appCode: String
	let channel: String
	let subChannel: String
	let language: String
	let platform = "Windows"
	let source = "launcher"

	private enum CodingKeys: String, CodingKey {
		case appCode = "appcode"
		case channel
		case subChannel = "sub_channel"
		case language, platform, source
	}
}

private struct GryphlineLatestGameRequest: Encodable {
	let appCode: String
	let channel: String
	let subChannel: String
	let version: String
	let launcherAppCode: String

	private enum CodingKeys: String, CodingKey {
		case appCode = "appcode"
		case channel
		case subChannel = "sub_channel"
		case version
		case launcherAppCode = "launcher_appcode"
	}
}

private struct GryphlineBatchResponse: Decodable {
	let responses: [GryphlineProxyResponse]

	private enum CodingKeys: String, CodingKey {
		case responses = "proxy_rsps"
	}
}

private struct GryphlineProxyResponse: Decodable {
	let kind: String
	let latestGame: GryphlineLatestGame?
	let mainBackground: GryphlineMainBackgroundResponse?

	private enum CodingKeys: String, CodingKey {
		case kind
		case latestGame = "get_latest_game_rsp"
		case mainBackground = "get_main_bg_image_rsp"
	}
}

private struct GryphlineMainBackgroundResponse: Decodable {
	let image: GryphlineBackgroundImage

	private enum CodingKeys: String, CodingKey {
		case image = "main_bg_image"
	}
}

private struct GryphlineBackgroundImage: Decodable {
	let url: URL
	let md5: String
}

private struct GryphlineLatestGame: Decodable {
	let version: String
	let package: GryphlinePackage

	private enum CodingKeys: String, CodingKey {
		case version
		case package = "pkg"
	}
}

private struct GryphlinePackage: Decodable {
	let filePath: URL
	let totalSize: String

	private enum CodingKeys: String, CodingKey {
		case filePath = "file_path"
		case totalSize = "total_size"
	}
}

private struct GryphlineManifestEntry: Decodable {
	let path: String
	let md5: String
	let size: Int64
}
