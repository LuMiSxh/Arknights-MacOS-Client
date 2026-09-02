// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Adapts Hypergryph's launcher metadata and per-file manifest to the launcher's normal
/// installation pipeline. China remains selected by the client; no vendor launcher is run.
actor HypergryphLauncherAPI {
	private static let metadataURL = URL(
		string: "https://launcher.hypergryph.com/api/proxy/batch_proxy"
	)!
	private static let webMetadataURL = URL(
		string: "https://launcher.hypergryph.com/api/proxy/web/batch_proxy"
	)!
	private static let gameAppCode = "GzD1CpaWgmSq1wew"
	private static let launcherAppCode = "abYeZZ16BPluCFyT"
	private static let channel = "1"
	private static let sequence = "5"

	private let loader: BoundedHTTPDataLoader
	private let maximumAPIResponseBytes: Int
	private let maximumManifestResponseBytes: Int
	private var latestPackage: HypergryphPackage?

	init(
		session: URLSession,
		maximumAPIResponseBytes: Int,
		maximumManifestResponseBytes: Int
	) {
		loader = BoundedHTTPDataLoader(session: session) { url in
			guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
			return host == "launcher.hypergryph.com" || host.hasSuffix(".hycdn.cn")
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
		let payload = HypergryphBatchRequest(
			sequence: Self.sequence,
			requests: [
				HypergryphProxyRequest(
					kind: "get_main_bg_image",
					latestGame: nil,
					mainBackground: HypergryphCommonRequest(
						appCode: Self.gameAppCode,
						channel: Self.channel,
						subChannel: Self.channel,
						language: "zh-cn"
					)
				)
			]
		)
		let envelope = try await response(for: payload, at: Self.webMetadataURL)
		guard
			let image = envelope.responses.first(where: { $0.kind == "get_main_bg_image" })?
				.mainBackground?.image,
			Self.isHypergryphAssetURL(image.url),
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
				HypergryphManifestEntry.self,
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

	private func package() async throws -> HypergryphPackage {
		if let latestPackage { return latestPackage }
		let latest = try await latestGame()
		latestPackage = latest.package
		return latest.package
	}

	private func latestGame() async throws -> HypergryphLatestGame {
		let payload = HypergryphBatchRequest(
			sequence: Self.sequence,
			requests: [
				HypergryphProxyRequest(
					kind: "get_latest_game",
					latestGame: HypergryphLatestGameRequest(
						appCode: Self.gameAppCode,
						channel: Self.channel,
						subChannel: Self.channel,
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
		for payload: HypergryphBatchRequest,
		at url: URL
	) async throws -> HypergryphBatchResponse {
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(payload)
		let (data, response) = try await loader.data(
			for: request,
			maximumBytes: maximumAPIResponseBytes
		)
		guard response.statusCode == 200 else { throw LauncherError.invalidResponse }
		return try JSONDecoder().decode(HypergryphBatchResponse.self, from: data)
	}

	private static func isHypergryphAssetURL(_ url: URL) -> Bool {
		url.scheme == "https" && url.user == nil && url.password == nil && url.port == nil
			&& url.host?.lowercased().hasSuffix(".hycdn.cn") == true
	}

	private static func cdnOrigin(for url: URL) throws -> URL {
		guard
			url.scheme == "https",
			url.user == nil,
			url.password == nil,
			url.port == nil,
			let host = url.host?.lowercased(),
			host.hasSuffix(".hycdn.cn")
		else { throw LauncherError.invalidResponse }
		var components = URLComponents()
		components.scheme = "https"
		components.host = host
		guard let origin = components.url else { throw LauncherError.invalidResponse }
		return origin
	}

	private static func cdnSource(for url: URL) throws -> String {
		_ = try cdnOrigin(for: url)
		guard url.query == nil, url.fragment == nil else { throw LauncherError.invalidResponse }
		return try GameInstaller.safeRelativePath(url.path)
	}
}

private struct HypergryphBatchRequest: Encodable {
	let sequence: String
	let requests: [HypergryphProxyRequest]

	private enum CodingKeys: String, CodingKey {
		case sequence = "seq"
		case requests = "proxy_reqs"
	}
}

private struct HypergryphProxyRequest: Encodable {
	let kind: String
	let latestGame: HypergryphLatestGameRequest?
	let mainBackground: HypergryphCommonRequest?

	private enum CodingKeys: String, CodingKey {
		case kind
		case latestGame = "get_latest_game_req"
		case mainBackground = "get_main_bg_image_req"
	}
}

private struct HypergryphCommonRequest: Encodable {
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

private struct HypergryphLatestGameRequest: Encodable {
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

private struct HypergryphBatchResponse: Decodable {
	let responses: [HypergryphProxyResponse]

	private enum CodingKeys: String, CodingKey {
		case responses = "proxy_rsps"
	}
}

private struct HypergryphProxyResponse: Decodable {
	let kind: String
	let latestGame: HypergryphLatestGame?
	let mainBackground: HypergryphMainBackgroundResponse?

	private enum CodingKeys: String, CodingKey {
		case kind
		case latestGame = "get_latest_game_rsp"
		case mainBackground = "get_main_bg_image_rsp"
	}
}

private struct HypergryphMainBackgroundResponse: Decodable {
	let image: HypergryphBackgroundImage

	private enum CodingKeys: String, CodingKey {
		case image = "main_bg_image"
	}
}

private struct HypergryphBackgroundImage: Decodable {
	let url: URL
	let md5: String
}

private struct HypergryphLatestGame: Decodable {
	let version: String
	let package: HypergryphPackage

	private enum CodingKeys: String, CodingKey {
		case version
		case package = "pkg"
	}
}

private struct HypergryphPackage: Decodable {
	let filePath: URL
	let totalSize: String

	private enum CodingKeys: String, CodingKey {
		case filePath = "file_path"
		case totalSize = "total_size"
	}
}

private struct HypergryphManifestEntry: Decodable {
	let path: String
	let md5: String
	let size: Int64
}
