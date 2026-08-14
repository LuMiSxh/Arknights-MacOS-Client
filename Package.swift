// swift-tools-version: 6.2
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let package = Package(
	name: "ArknightsClient",
	platforms: [
		.macOS(.v26)
	],
	products: [
		.executable(name: "ArknightsClient", targets: ["ArknightsClient"])
	],
	targets: [
		.executableTarget(
			name: "ArknightsClient",
			path: "Sources/ArknightsClient"
		),
		.testTarget(
			name: "ArknightsClientTests",
			dependencies: ["ArknightsClient"],
			path: "Tests/ArknightsClientTests"
		),
	]
)
