// swift-tools-version: 6.2
// SPDX-License-Identifier: MPL-2.0

import Foundation
import PackageDescription

let useCopiedLocalizationResources =
	ProcessInfo.processInfo.environment["ARKNIGHTS_CLIENT_SWIFT_TESTS"] == "1"

func localizationResource(_ path: String) -> Resource {
	useCopiedLocalizationResources ? .copy(path) : .process(path)
}

let appResources: [Resource] =
	useCopiedLocalizationResources
	// Xcode 27 still scans individual .xcstrings files for native symbols even with .copy.
	// Copying the directory keeps test resources available without scheduling that step.
	? [
		.copy("Resources"),
		// Keep noncatalog assets at the bundle root for Bundle.url(forResource:).
		.copy("Resources/GameIconBackground.png"),
		.copy("Resources/OperatorIconFrame.svg"),
		.copy("Resources/WallpaperTags.json"),
	]
	: [
		.copy("Resources/GameIconBackground.png"),
		.copy("Resources/OperatorIconFrame.svg"),
		.copy("Resources/WallpaperTags.json"),
		localizationResource("Resources/Customization.xcstrings"),
		localizationResource("Resources/Launcher.xcstrings"),
		localizationResource("Resources/Localizable.xcstrings"),
		localizationResource("Resources/Settings.xcstrings"),
	]

let package = Package(
	name: "ArknightsClient",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.executable(name: "ArknightsClient", targets: ["ArknightsClient"])
	],
	dependencies: [
		.package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.6"),
		.package(url: "https://github.com/SvenTiigi/YouTubePlayerKit.git", from: "2.0.0"),
	],
	targets: [
		.systemLibrary(
			name: "CCommonCrypto",
			path: "RuntimeSupport/CommonCrypto"
		),
		.executableTarget(
			name: "ArknightsClient",
			dependencies: [
				"CCommonCrypto",
				.product(name: "YouTubePlayerKit", package: "YouTubePlayerKit"),
				.product(name: "Sparkle", package: "Sparkle"),
			],
			path: "Sources/ArknightsClient",
			resources: appResources
		),
		.testTarget(
			name: "ArknightsClientTests",
			dependencies: ["ArknightsClient"],
			path: "Tests/ArknightsClientTests"
		),
		.testTarget(
			name: "ArknightsClientIntegrationTests",
			dependencies: ["ArknightsClient"],
			path: "Tests/ArknightsClientIntegrationTests",
			resources: [.copy("Fixtures")]
		),
		.testTarget(
			name: "ArknightsClientLiveContractTests",
			dependencies: ["ArknightsClient"],
			path: "Tests/ArknightsClientLiveContractTests"
		),
	]
)
