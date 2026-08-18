// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

struct LauncherBranding: Decodable, Sendable {
	let launcherBackgroundImage: URL?
	let launcherBackgroundImageCRC64: String?
	let copyrightInformation: String?
	let privacyPolicy: URL?
	let userAgreement: URL?
	let noticePopOpen: Bool?
	let noticeContent: String?

	enum CodingKeys: String, CodingKey {
		case launcherBackgroundImage = "launcherBackgroundImg"
		case launcherBackgroundImageCRC64 = "launcherBackgroundImgCrc64"
		case copyrightInformation
		case privacyPolicy
		case userAgreement
		case noticePopOpen
		case noticeContent
	}

	init(
		launcherBackgroundImage: URL?,
		launcherBackgroundImageCRC64: String?,
		copyrightInformation: String?,
		privacyPolicy: URL?,
		userAgreement: URL?,
		noticePopOpen: Bool?,
		noticeContent: String?
	) {
		self.launcherBackgroundImage = launcherBackgroundImage
		self.launcherBackgroundImageCRC64 = launcherBackgroundImageCRC64
		self.copyrightInformation = copyrightInformation
		self.privacyPolicy = privacyPolicy
		self.userAgreement = userAgreement
		self.noticePopOpen = noticePopOpen
		self.noticeContent = noticeContent
	}

	init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		launcherBackgroundImage = try container.decodeIfPresent(
			String.self, forKey: .launcherBackgroundImage
		)
		.flatMap { $0.isEmpty ? nil : URL(string: $0) }

		launcherBackgroundImageCRC64 = try container.decodeIfPresent(
			String.self, forKey: .launcherBackgroundImageCRC64)
		copyrightInformation = try container.decodeIfPresent(
			String.self, forKey: .copyrightInformation)

		privacyPolicy = try container.decodeIfPresent(String.self, forKey: .privacyPolicy)
			.flatMap { $0.isEmpty ? nil : URL(string: $0) }

		userAgreement = try container.decodeIfPresent(String.self, forKey: .userAgreement)
			.flatMap { $0.isEmpty ? nil : URL(string: $0) }

		noticePopOpen = try container.decodeIfPresent(Bool.self, forKey: .noticePopOpen)
		noticeContent = try container.decodeIfPresent(String.self, forKey: .noticeContent)
	}
}

/// Downloads and disk-caches the launcher background and official logo by CRC64, so
/// unchanged artwork across launches or branding refreshes doesn't refetch.
actor ArtworkCache {
	private static let officialLogoURL = URL(
		string:
			"https://webusstatic.yo-star.com/arknights-us/arknights-us-website/main/h5/assets/logo-4f95ced5.png"
	)!

	private let session: URLSession
	private let directory: URL

	init(
		session: URLSession = .shared,
		directory: URL = AppPaths().artworkCache
	) {
		self.session = session
		self.directory = directory
	}

	func imageData(for branding: LauncherBranding) async throws -> Data? {
		guard let sourceURL = branding.launcherBackgroundImage else { return nil }
		let cacheKey = branding.launcherBackgroundImageCRC64 ?? sourceURL.lastPathComponent
		let safeKey = cacheKey.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
		guard !safeKey.isEmpty else { return nil }

		let fileManager = FileManager.default
		let cachedURL = directory.appending(path: "\(safeKey).jpg")
		if let data = try? Data(contentsOf: cachedURL), !data.isEmpty {
			return data
		}

		var request = URLRequest(url: sourceURL)
		request.cachePolicy = .reloadRevalidatingCacheData
		let (data, response) = try await session.data(for: request)
		guard
			let http = response as? HTTPURLResponse,
			http.statusCode == 200,
			data.count <= 25 * 1_024 * 1_024
		else {
			throw LauncherError.invalidResponse
		}

		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		try data.write(to: cachedURL, options: .atomic)
		return data
	}

	func officialLogoData() async throws -> Data {
		let cachedURL = directory.appending(path: "official-arknights-logo.png")
		if let data = try? Data(contentsOf: cachedURL), !data.isEmpty {
			return data
		}

		var request = URLRequest(url: Self.officialLogoURL)
		request.cachePolicy = .reloadRevalidatingCacheData
		let (data, response) = try await session.data(for: request)
		guard
			let http = response as? HTTPURLResponse,
			http.statusCode == 200,
			data.count <= 2 * 1_024 * 1_024
		else {
			throw LauncherError.invalidResponse
		}

		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try data.write(to: cachedURL, options: .atomic)
		return data
	}
}
