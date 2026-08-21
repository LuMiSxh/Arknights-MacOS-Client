// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Runs Apple's Rosetta installer after the UI has explicitly confirmed license acceptance.
/// The caller must inspect the exit status and repeat the functional Intel-process probe.
enum RosettaInstaller {
	private static let softwareUpdateTool = URL(filePath: "/usr/sbin/softwareupdate")

	static func install(
		runProcess:
			@escaping @Sendable (URL, [String]) async throws
			-> IntelTranslationProcessResult = IntelTranslationProcess.run
	) async throws -> IntelTranslationProcessResult {
		try await runProcess(
			softwareUpdateTool,
			["--install-rosetta", "--agree-to-license"]
		)
	}
}
