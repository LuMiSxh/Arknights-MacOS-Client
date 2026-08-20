// swift-tools-version: 6.2
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let package = Package(
	name: "ArknightsClient",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.executable(name: "ArknightsClient", targets: ["ArknightsClient"])
	],
	dependencies: [
		.package(url: "https://github.com/SvenTiigi/YouTubePlayerKit.git", from: "2.0.0")
	],
	targets: [
		.executableTarget(
			name: "ArknightsClient",
			dependencies: [
				.product(name: "YouTubePlayerKit", package: "YouTubePlayerKit")
			],
			path: "Sources/ArknightsClient",
			resources: [
				.copy("Resources/GameIconBackground.png")
			]
		),
		.testTarget(
			name: "ArknightsClientTests",
			dependencies: ["ArknightsClient"],
			path: "Tests/ArknightsClientTests"
		),
	]
)
