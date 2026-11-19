// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameInstallation

struct GameInstallerDiskSpaceTests {
	private static let body = Data((0..<4_096).map { UInt8($0 % 251) })

	@Test
	func repairOfCompleteInstallNeedsNoFreeSpaceButMissingFileNeedsItsSize() async throws {
		let fixture = try InstallerFixture.make(body: Self.body)
		defer { fixture.remove() }
		let installer = GameInstaller(
			api: fixture.installer.api,
			session: fixture.route.session,
			compatibilityManager: GameCompatibilityManager(),
			availableCapacity: { _ in 100 }
		)

		try Self.body.write(to: fixture.destination)
		let repaired = try await installer.install(
			configuration: installerTestConfiguration,
			region: .global,
			into: fixture.directory,
			verifyAllExistingFiles: true
		) { _ in }
		#expect(repaired.downloadedFiles == 0)

		try FileManager.default.removeItem(at: fixture.destination)
		await #expect(throws: InstallerError.self) {
			try await installer.install(
				configuration: installerTestConfiguration,
				region: .global,
				into: fixture.directory,
				verifyAllExistingFiles: true
			) { _ in }
		}
	}
}
