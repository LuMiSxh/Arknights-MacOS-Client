// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The network surface `LauncherViewModel` depends on; lets tests substitute a fake
/// implementation instead of hitting Yostar's real API.
protocol LauncherAPIProviding: Sendable {
	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration
	func branding(region: GameRegion) async throws -> LauncherBranding
	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration
	func manifest(for configuration: GameConfiguration, region: GameRegion) async throws
		-> GameManifest
}

/// The installer surface `LauncherViewModel` depends on, so tests can substitute a fake
/// installer instead of downloading real game files.
protocol GameInstalling: Sendable {
	func install(
		configuration: GameConfiguration,
		region: GameRegion,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool,
		progress: @escaping @Sendable (DownloadProgress) async -> Void
	) async throws -> InstallResult
}

extension LauncherAPI: LauncherAPIProviding {}
extension GameInstaller: GameInstalling {}
