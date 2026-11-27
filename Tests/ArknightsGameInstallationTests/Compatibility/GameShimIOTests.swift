// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

// A crash between moving the original aside and moving the shim in leaves the original only at
// the backup path. The next swap must keep it.
@Test
func swapKeepsTheOriginalWhenOnlyTheBackupSurvivedACrash() throws {
	let temporary = try TemporaryDirectory("GameShimIOTests")
	defer { temporary.remove() }
	let helper = temporary.url.appending(path: "helper.exe")
	let backup = temporary.url.appending(path: "helper.exe.original")
	let shim = temporary.url.appending(path: "shim.exe")
	let original = Data("official helper".utf8)
	let shimData = Data("launcher shim".utf8)
	try original.write(to: backup)
	try shimData.write(to: shim)

	try GameShimIO.swapHelper(
		at: helper,
		with: shim,
		backupURL: backup,
		isCurrentlyInstalledShim: false,
		temporaryPrefix: "shim-",
		previousPrefix: "previous-",
		fileManager: .default,
		log: nil
	) {}

	#expect(try Data(contentsOf: helper) == shimData)
	#expect(try Data(contentsOf: backup) == original)
}
