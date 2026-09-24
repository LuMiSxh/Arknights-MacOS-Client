// swift-tools-version: 6.2
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let appResources: [Resource] = [
	.copy("Resources/GameIconBackground.png"),
	.copy("Resources/OperatorIconFrame.svg"),
	.copy("Resources/WallpaperTags.json"),
]

let package = Package(
	name: "ArknightsClient",
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
