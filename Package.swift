// swift-tools-version: 6.4
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let appResources: [Resource] = [
	.copy("Resources/AppIconTintSource.png"),
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
		.target(
			name: "ArknightsInfrastructure",
			path: "Sources/ArknightsInfrastructure"
		),
		.target(
			name: "ArknightsCore",
			dependencies: ["ArknightsInfrastructure"],
			path: "Sources/ArknightsCore",
			resources: appResources
		),
		.target(
			name: "ArknightsCustomization",
			dependencies: ["ArknightsInfrastructure", "ArknightsCore"],
			path: "Sources/ArknightsCustomization"
		),
		.target(
			name: "ArknightsGameInstallation",
			dependencies: [
				"ArknightsInfrastructure",
				"ArknightsCore",
				"ArknightsCustomization",
				"CCommonCrypto",
			],
			path: "Sources/ArknightsGameInstallation"
		),
		.target(
			name: "ArknightsGameRuntime",
			dependencies: [
				"ArknightsInfrastructure",
				"ArknightsCore",
				"ArknightsCustomization",
				"ArknightsGameInstallation",
			],
			path: "Sources/ArknightsGameRuntime"
		),
		.target(
			name: "ArknightsPresence",
			dependencies: ["ArknightsInfrastructure", "ArknightsCore"],
			path: "Sources/ArknightsPresence"
		),
		.target(
			name: "ArknightsAudio",
			dependencies: [
				"ArknightsCore",
				"ArknightsCustomization",
				.product(name: "YouTubePlayerKit", package: "YouTubePlayerKit"),
			],
			path: "Sources/ArknightsAudio",
			swiftSettings: [.defaultIsolation(MainActor.self)]
		),
		.target(
			name: "ArknightsOnboarding",
			dependencies: [
				"ArknightsCore",
				"ArknightsCustomization",
				"ArknightsGameInstallation",
				"ArknightsGameRuntime",
			],
			path: "Sources/ArknightsOnboarding",
			swiftSettings: [.defaultIsolation(MainActor.self)]
		),
		.target(
			name: "ArknightsLauncherUI",
			dependencies: [
				"ArknightsInfrastructure",
				"ArknightsCore",
				"ArknightsCustomization",
				"ArknightsGameInstallation",
				"ArknightsGameRuntime",
				"ArknightsPresence",
				"ArknightsAudio",
				"ArknightsOnboarding",
				.product(name: "Sparkle", package: "Sparkle"),
			],
			path: "Sources/ArknightsLauncherUI",
			swiftSettings: [.defaultIsolation(MainActor.self)]
		),
		.executableTarget(
			name: "ArknightsClient",
			dependencies: [
				"ArknightsCore",
				"ArknightsAudio",
				"ArknightsOnboarding",
				"ArknightsLauncherUI",
			],
			path: "Sources/ArknightsClient",
			swiftSettings: [.defaultIsolation(MainActor.self)]
		),
		.target(
			name: "ArknightsTestSupport",
			dependencies: ["ArknightsCore", "ArknightsGameRuntime"],
			path: "Tests/ArknightsTestSupport"
		),
		.testTarget(
			name: "ArknightsClientTests",
			dependencies: [
				"ArknightsClient",
				"ArknightsLauncherUI",
				"ArknightsCore",
				.product(name: "Sparkle", package: "Sparkle"),
			],
			path: "Tests/ArknightsClientTests"
		),
		.testTarget(
			name: "ArknightsLauncherUITests",
			dependencies: [
				"ArknightsLauncherUI",
				"ArknightsTestSupport",
				"ArknightsGameRuntime",
				"ArknightsGameInstallation",
				"ArknightsCustomization",
				"ArknightsCore",
				"ArknightsInfrastructure",
				.product(name: "Sparkle", package: "Sparkle"),
			],
			path: "Tests/ArknightsLauncherUITests"
		),
		.testTarget(
			name: "ArknightsPresenceTests",
			dependencies: [
				"ArknightsPresence",
				"ArknightsCore",
				"ArknightsInfrastructure",
				"ArknightsTestSupport",
			],
			path: "Tests/ArknightsPresenceTests"
		),
		.testTarget(
			name: "ArknightsAudioTests",
			dependencies: [
				"ArknightsTestSupport",
				"ArknightsAudio",
				"ArknightsCustomization",
				"ArknightsCore",
				"ArknightsInfrastructure",
				.product(name: "YouTubePlayerKit", package: "YouTubePlayerKit"),
			],
			path: "Tests/ArknightsAudioTests"
		),
		.testTarget(
			name: "ArknightsCoreTests",
			dependencies: ["ArknightsCore", "ArknightsTestSupport"],
			path: "Tests/ArknightsCoreTests"
		),
		.testTarget(
			name: "ArknightsCustomizationTests",
			dependencies: [
				"ArknightsCustomization",
				"ArknightsTestSupport",
				"ArknightsCore",
				"ArknightsInfrastructure",
			],
			path: "Tests/ArknightsCustomizationTests"
		),
		.testTarget(
			name: "ArknightsGameInstallationTests",
			dependencies: [
				"ArknightsGameInstallation",
				"ArknightsCustomization",
				"ArknightsCore",
				"ArknightsInfrastructure",
				"ArknightsTestSupport",
			],
			path: "Tests/ArknightsGameInstallationTests"
		),
		.testTarget(
			name: "ArknightsGameRuntimeTests",
			dependencies: [
				"ArknightsGameRuntime",
				"ArknightsTestSupport",
				"ArknightsGameInstallation",
				"ArknightsCustomization",
				"ArknightsCore",
				"ArknightsInfrastructure",
			],
			path: "Tests/ArknightsGameRuntimeTests"
		),
		.testTarget(
			name: "ArknightsOnboardingTests",
			dependencies: [
				"ArknightsOnboarding",
				"ArknightsGameRuntime",
				"ArknightsGameInstallation",
				"ArknightsCustomization",
				"ArknightsCore",
				"ArknightsInfrastructure",
				"ArknightsTestSupport",
			],
			path: "Tests/ArknightsOnboardingTests"
		),
		.testTarget(
			name: "ArknightsInfrastructureTests",
			dependencies: ["ArknightsInfrastructure", "ArknightsTestSupport"],
			path: "Tests/ArknightsInfrastructureTests"
		),
		.testTarget(
			name: "ArknightsClientIntegrationTests",
			dependencies: [
				"ArknightsLauncherUI",
				"ArknightsOnboarding",
				"ArknightsGameRuntime",
				"ArknightsGameInstallation",
				"ArknightsCore",
				"ArknightsInfrastructure",
				"ArknightsTestSupport",
			],
			path: "Tests/ArknightsClientIntegrationTests",
			resources: [.copy("Fixtures")]
		),
		.testTarget(
			name: "ArknightsClientLiveContractTests",
			dependencies: [
				"ArknightsGameInstallation",
				"ArknightsCore",
			],
			path: "Tests/ArknightsClientLiveContractTests"
		),
	]
)
