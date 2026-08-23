// swift-tools-version: 6.2
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

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
		.package(url: "https://github.com/SvenTiigi/YouTubePlayerKit.git", from: "2.0.0")
	],
	targets: [
		.executableTarget(
			name: "ArknightsClient",
			dependencies: [
				.product(name: "YouTubePlayerKit", package: "YouTubePlayerKit")
			],
			path: "Sources/ArknightsClient",
			exclude: [
				"Resources/Customization.xcstrings",
				"Resources/Launcher.xcstrings",
				"Resources/Localizable.xcstrings",
				"Resources/Settings.xcstrings"
			],
			resources: [
				.copy("Resources/GameIconBackground.png"),
				.copy("Resources/OperatorIconFrame.svg"),
				.process("Resources/en.lproj"),
				.process("Resources/de.lproj"),
			]
		),
		.testTarget(
			name: "ArknightsClientTests",
			dependencies: ["ArknightsClient"],
			path: "Tests/ArknightsClientTests"
		),
	]
)
