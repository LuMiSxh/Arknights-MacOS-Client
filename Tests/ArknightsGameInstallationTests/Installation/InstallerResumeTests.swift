// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

@Suite(.serialized)
struct InstallerResumeTests {
	@Test(arguments: [
		(
			"release validators",
			[
				"ETag": "\"930F52526F9F34822294B1B0F8AD5990\"",
				"Last-Modified": "Wed, 12 Aug 2026 10:30:34 GMT",
			],
			Optional("\"930F52526F9F34822294B1B0F8AD5990\""),
			Optional("Wed, 12 Aug 2026 10:30:34 GMT"),
			Optional("\"930F52526F9F34822294B1B0F8AD5990\""),
			false
		),
		(
			"weak ETag with Last-Modified",
			["ETag": "W/\"weak\"", "Last-Modified": "Wed, 12 Aug 2026 10:30:34 GMT"],
			Optional("W/\"weak\""),
			Optional("Wed, 12 Aug 2026 10:30:34 GMT"),
			nil,
			false
		),
		(
			"Last-Modified only", ["Last-Modified": "Wed, 12 Aug 2026 10:30:34 GMT"], nil,
			Optional("Wed, 12 Aug 2026 10:30:34 GMT"), nil, false
		),
		("no validators", [:], nil, nil, nil, false),
		("empty ETag", ["ETag": ""], nil, nil, nil, true),
		("oversized ETag", ["ETag": String(repeating: "x", count: 4_097)], nil, nil, nil, true),
		(
			"control in Last-Modified", ["Last-Modified": "Wed, 12 Aug\u{0085} 2026"], nil, nil,
			nil, true
		),
	])
	func resumeMetadataValidatesResponseHeaders(
		scenario: String,
		headers: [String: String],
		expectedEntityTag: String?,
		expectedLastModified: String?,
		expectedIfRange: String?,
		rejectsResponse: Bool
	) throws {
		let response = makeHTTPResponse(
			url: URL(string: "https://cdn.example/game.dat")!,
			status: 206,
			headers: headers
		)
		if rejectsResponse {
			#expect(throws: LauncherError.self) {
				try GameInstaller.resumeMetadata(from: response, manifestHash: "fixture")
			}
			return
		}

		let metadata = try GameInstaller.resumeMetadata(from: response, manifestHash: "fixture")
		let comment = Comment(rawValue: scenario)
		#expect(metadata.manifestHash == "fixture", comment)
		#expect(metadata.entityTag == expectedEntityTag, comment)
		#expect(metadata.lastModified == expectedLastModified, comment)
		#expect(metadata.ifRangeValue == expectedIfRange, comment)
	}
}
