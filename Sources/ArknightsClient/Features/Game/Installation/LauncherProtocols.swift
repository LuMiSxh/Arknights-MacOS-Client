// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The Yostar network surface used by refresh and installation flows; lets tests substitute a
/// fixture instead of hitting the live API.
protocol LauncherAPIProviding: Sendable {
	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration
	func branding(region: GameRegion) async throws -> LauncherBranding
	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration
	func manifest(for configuration: GameConfiguration, region: GameRegion) async throws
		-> GameManifest
}

/// The installer surface owned by `InstallationController`, so tests can substitute a fixture
/// instead of downloading real game files.
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
