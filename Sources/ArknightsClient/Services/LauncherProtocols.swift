// SPDX-License-Identifier: MPL-2.0

import Foundation

protocol LauncherAPIProviding: Sendable {
	func gameConfiguration() async throws -> GameConfiguration
	func branding() async throws -> LauncherBranding
	func cdnConfiguration() async throws -> CDNConfiguration
	func manifest(for configuration: GameConfiguration) async throws -> GameManifest
}

protocol GameInstalling: Sendable {
	func install(
		configuration: GameConfiguration,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool,
		progress: @escaping @Sendable (DownloadProgress) async -> Void
	) async throws -> InstallResult
}

extension LauncherAPI: LauncherAPIProviding {}
extension GameInstaller: GameInstalling {}
