// SPDX-License-Identifier: MPL-2.0

import Foundation

package struct LauncherBranding: Decodable, Sendable {
	package let launcherBackgroundImage: URL?
	package let launcherBackgroundImageCRC64: String?
	package let copyrightInformation: String?
	package let privacyPolicy: URL?
	package let userAgreement: URL?
	package let noticePopOpen: Bool?
	package let noticeContent: String?

	enum CodingKeys: String, CodingKey {
		case launcherBackgroundImage = "launcherBackgroundImg"
		case launcherBackgroundImageCRC64 = "launcherBackgroundImgCrc64"
		case copyrightInformation
		case privacyPolicy
		case userAgreement
		case noticePopOpen
		case noticeContent
	}

	package init(
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

	package init(from decoder: any Decoder) throws {
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
