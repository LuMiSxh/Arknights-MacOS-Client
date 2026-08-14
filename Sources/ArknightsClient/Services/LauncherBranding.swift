// SPDX-License-Identifier: MPL-2.0

import Foundation

struct LauncherBranding: Decodable, Sendable {
	let launcherBackgroundImage: URL?
	let launcherBackgroundImageCRC64: String?
	let copyrightInformation: String?
	let privacyPolicy: URL?
	let userAgreement: URL?

	enum CodingKeys: String, CodingKey {
		case launcherBackgroundImage = "launcherBackgroundImg"
		case launcherBackgroundImageCRC64 = "launcherBackgroundImgCrc64"
		case copyrightInformation
		case privacyPolicy
		case userAgreement
	}
}

actor ArtworkCache {
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
			data.count <= 25 * 1_024 * 1_024,
			http.mimeType?.hasPrefix("image/") == true
		else {
			throw LauncherError.invalidResponse
		}

		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		try data.write(to: cachedURL, options: .atomic)
		return data
	}
}
