// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsInfrastructure
import Foundation

/// Adapts the Hypergryph-family launcher metadata (China, China Bilibili, Taiwan) and per-file
/// manifest to the launcher's normal installation pipeline. The client selects the region; no
/// vendor launcher is run.
actor HypergryphLauncherAPI {
	private static let sequence = "5"

	private let loader: BoundedHTTPDataLoader
	private let maximumAPIResponseBytes: Int
	private let maximumManifestResponseBytes: Int
	private var latestPackages: [String: HypergryphPackage] = [:]

	init(
		session: URLSession = .shared,
		maximumAPIResponseBytes: Int = AppConstants.Network.yostarAPIResponseMaximumBytes,
		maximumManifestResponseBytes: Int = AppConstants.Network.yostarManifestMaximumBytes
	) {
		loader = BoundedHTTPDataLoader(
			session: session,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
		)
		self.maximumAPIResponseBytes = maximumAPIResponseBytes
		self.maximumManifestResponseBytes = maximumManifestResponseBytes
	}

	func gameConfiguration(
		for profile: HypergryphProfile
	) async throws
		-> GameConfiguration
	{
		let latest = try await latestGame(for: profile)
		latestPackages[profile.channel] = latest.package
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

	func branding(for profile: HypergryphProfile) async throws -> LauncherBranding {
		let payload = HypergryphBatchRequest(
			sequence: Self.sequence,
			requests: [
				HypergryphProxyRequest(
					kind: "get_main_bg_image",
					latestGame: nil,
					mainBackground: HypergryphCommonRequest(
						appCode: profile.gameAppCode,
						channel: profile.channel,
						subChannel: profile.channel,
						language: profile.language
					)
				)
			]
		)
		let envelope = try await response(
			for: payload, at: profile.webMetadataURL, profile: profile)
		guard
			let image = envelope.responses.first(where: { $0.kind == "get_main_bg_image" })?
				.mainBackground?.image,
			DownloadHTTPPolicy.isAllowedSource(image.url, for: profile.region),
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

	func cdnConfiguration(
		for profile: HypergryphProfile
	) async throws
		-> CDNConfiguration
	{
		let package = try await package(for: profile)
		let baseURL = try Self.cdnOrigin(for: package.filePath, profile: profile)
		return CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
	}

	func manifest(
		for configuration: GameConfiguration,
		profile: HypergryphProfile
	) async throws -> GameManifest {
		guard let fileBaseURL = URL(string: configuration.gameLatestFilePath) else {
			throw LauncherError.invalidResponse
		}
		_ = try Self.cdnOrigin(for: fileBaseURL, profile: profile)
		let source = try GameInstaller.safeRelativePath(fileBaseURL.path)
		var request = URLRequest(url: fileBaseURL.appending(path: "game_files"))
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		let (encrypted, response) = try await loader.data(
			for: request,
			maximumBytes: maximumManifestResponseBytes,
			redirectValidator: DownloadHTTPPolicy.redirectValidator(for: profile.region)
		)
		guard response.statusCode == 200 else { throw LauncherError.invalidResponse }
		let decrypted = try HypergryphManifestCipher.decrypt(encrypted)
		guard let text = String(data: decrypted, encoding: .utf8) else {
			throw LauncherError.invalidResponse
		}
		let decoder = JSONDecoder()
		let files = try text.split(whereSeparator: \.isNewline).map { line in
			let entry = try decoder.decode(HypergryphManifestEntry.self, from: Data(line.utf8))
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

	private func package(for profile: HypergryphProfile) async throws -> HypergryphPackage {
		if let latestPackage = latestPackages[profile.channel] { return latestPackage }
		let latest = try await latestGame(for: profile)
		latestPackages[profile.channel] = latest.package
		return latest.package
	}

	private func latestGame(for profile: HypergryphProfile) async throws -> HypergryphLatestGame {
		let payload = HypergryphBatchRequest(
			sequence: Self.sequence,
			requests: [
				HypergryphProxyRequest(
					kind: "get_latest_game",
					latestGame: HypergryphLatestGameRequest(
						appCode: profile.gameAppCode,
						channel: profile.channel,
						subChannel: profile.channel,
						version: "",
						launcherAppCode: profile.launcherAppCode
					),
					mainBackground: nil
				)
			]
		)
		let envelope = try await response(for: payload, at: profile.metadataURL, profile: profile)
		guard
			let latest = envelope.responses.first(where: { $0.kind == "get_latest_game" })?
				.latestGame,
			!latest.version.isEmpty
		else { throw LauncherError.invalidResponse }
		_ = try Self.cdnOrigin(for: latest.package.filePath, profile: profile)
		return latest
	}

	private func response(
		for payload: HypergryphBatchRequest,
		at url: URL,
		profile: HypergryphProfile
	) async throws -> HypergryphBatchResponse {
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(payload)
		let (data, response) = try await loader.data(
			for: request,
			maximumBytes: maximumAPIResponseBytes,
			redirectValidator: profile.isAllowedMetadataURL
		)
		guard response.statusCode == 200 else { throw LauncherError.invalidResponse }
		return try JSONDecoder().decode(HypergryphBatchResponse.self, from: data)
	}

	private static func cdnOrigin(for url: URL, profile: HypergryphProfile) throws -> URL {
		guard
			DownloadHTTPPolicy.isAllowedSource(url, for: profile.region),
			let host = url.host?.lowercased(),
			url.query == nil,
			url.fragment == nil
		else { throw LauncherError.invalidResponse }
		var components = URLComponents()
		components.scheme = "https"
		components.host = host
		guard let origin = components.url else { throw LauncherError.invalidResponse }
		return origin
	}
}

/// Per-region constants for the shared Hypergryph launcher protocol.
struct HypergryphProfile: Sendable {
	let region: GameRegion
	let launcherHost: String
	let gameAppCode: String
	let launcherAppCode: String
	let channel: String
	let language: String

	var metadataURL: URL { URL(string: "https://\(launcherHost)/api/proxy/batch_proxy")! }
	var webMetadataURL: URL { URL(string: "https://\(launcherHost)/api/proxy/web/batch_proxy")! }

	@Sendable
	func isAllowedMetadataURL(_ url: URL) -> Bool {
		guard
			DownloadHTTPPolicy.isValidHTTPSURL(url),
			url.port == nil,
			let host = url.host?.lowercased()
		else { return false }
		return host == launcherHost || DownloadHTTPPolicy.isAllowedSource(url, for: region)
	}
}

extension GameRegion {
	var hypergryphProfile: HypergryphProfile? {
		switch self {
		case .china:
			HypergryphProfile(
				region: self,
				launcherHost: "launcher.hypergryph.com",
				gameAppCode: "GzD1CpaWgmSq1wew",
				launcherAppCode: "abYeZZ16BPluCFyT",
				channel: "1",
				language: "zh-cn"
			)
		case .chinaBilibili:
			HypergryphProfile(
				region: self,
				launcherHost: "launcher.hypergryph.com",
				gameAppCode: "GzD1CpaWgmSq1wew",
				launcherAppCode: "",
				channel: "2",
				language: "zh-cn"
			)
		case .taiwan:
			HypergryphProfile(
				region: self,
				launcherHost: "launcher.gryphline.com",
				gameAppCode: "uiCaUeGDB2htwXSv",
				launcherAppCode: "TiaytKBUIEdoEwRT",
				channel: "6",
				language: "zh-tw"
			)
		case .global, .japan, .korea: nil
		}
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
