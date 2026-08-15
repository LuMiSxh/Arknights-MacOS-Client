// SPDX-License-Identifier: MPL-2.0

import Foundation

extension WineRuntime {
	static func requiresPrefixUpdate(
		hasSystemRegistry: Bool,
		installedRevision: String?,
		expectedRevision: String
	) -> Bool {
		!hasSystemRegistry || installedRevision != expectedRevision
	}

	func preparePrefixIfNeeded(
		at prefixDirectory: URL,
		gameDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let fileManager = FileManager.default
		let systemRegistry = prefixDirectory.appending(path: "system.reg")
		let revisionMarker = prefixDirectory.appending(path: ".arknights-runtime-revision")
		let installedRevision = try? String(contentsOf: revisionMarker, encoding: .utf8)
		if Self.requiresPrefixUpdate(
			hasSystemRegistry: fileManager.fileExists(atPath: systemRegistry.path),
			installedRevision: installedRevision,
			expectedRevision: revision
		) {
			let exitStatus = try await runAndWait(
				executable: executableURL,
				arguments: ["wineboot.exe", "-u"],
				environment: environment,
				output: logHandle
			)
			guard exitStatus == 0 else {
				throw LauncherError.runtimeConfiguration(
					"Wine could not initialize its prefix (status \(exitStatus))."
				)
			}
			try revision.write(
				to: revisionMarker,
				atomically: true,
				encoding: .utf8
			)
		}

		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		try Self.installDXMT(
			from: runtimeRoot.appending(path: "DXMT", directoryHint: .isDirectory),
			in: prefixDirectory,
			fileManager: fileManager
		)
		try await configureCompatibilityOverridesIfNeeded(
			at: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)
		try WinePrefixConfigurator().configure(
			prefixDirectory: prefixDirectory,
			gameDirectory: gameDirectory
		)
	}

	func configureCompatibilityOverridesIfNeeded(
		at prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let marker = prefixDirectory.appending(path: ".arknights-runtime-configuration")
		let installedRevision = try? String(contentsOf: marker, encoding: .utf8)
		guard installedRevision != revision else { return }
		let globalKey = "HKCU\\Software\\Wine\\DllOverrides"
		for (name, value) in Self.globalRegistryOverrides.sorted(by: { $0.key < $1.key }) {
			let status = try await runAndWait(
				executable: executableURL,
				arguments: [
					"reg.exe", "add", globalKey, "/v", name, "/t", "REG_SZ", "/d", value, "/f",
				],
				environment: environment,
				output: logHandle
			)
			guard status == 0 else {
				throw LauncherError.runtimeConfiguration(
					"Wine could not apply the \(name) compatibility override (status \(status))."
				)
			}
		}
		let crashDialogStatus = try await runAndWait(
			executable: executableURL,
			arguments: [
				"reg.exe", "add", Self.crashDialogRegistryKey,
				"/v", Self.crashDialogRegistryValue,
				"/t", "REG_DWORD", "/d", "0", "/f",
			],
			environment: environment,
			output: logHandle
		)
		guard crashDialogStatus == 0 else {
			throw LauncherError.runtimeConfiguration(
				"Wine could not disable its crash dialog (status \(crashDialogStatus))."
			)
		}
		try revision.write(to: marker, atomically: true, encoding: .utf8)
	}

	static func installDXMT(
		from payloadDirectory: URL,
		in prefixDirectory: URL,
		fileManager: FileManager = .default
	) throws {
		let destinations = [("x64", "system32"), ("x32", "syswow64")]
		let sources = destinations.flatMap { architecture, _ in
			dxmtLibraryNames.map {
				payloadDirectory.appending(path: architecture).appending(path: $0)
			}
		}
		guard sources.allSatisfy({ fileManager.fileExists(atPath: $0.path) }) else {
			throw LauncherError.runtimeConfiguration("The bundled DXMT payload is incomplete.")
		}

		for (architecture, windowsDirectory) in destinations {
			let destinationDirectory =
				prefixDirectory
				.appending(path: "drive_c/windows", directoryHint: .isDirectory)
				.appending(path: windowsDirectory, directoryHint: .isDirectory)
			try fileManager.createDirectory(
				at: destinationDirectory,
				withIntermediateDirectories: true
			)
			for library in dxmtLibraryNames {
				let source = payloadDirectory.appending(path: architecture).appending(path: library)
				let destination = destinationDirectory.appending(path: library)
				if filesMatch(source, destination, fileManager: fileManager) { continue }
				if fileManager.fileExists(atPath: destination.path) {
					try fileManager.removeItem(at: destination)
				}
				try fileManager.copyItem(at: source, to: destination)
			}
		}
	}

	private static func filesMatch(_ lhs: URL, _ rhs: URL, fileManager: FileManager) -> Bool {
		guard
			let lhsValues = try? lhs.resourceValues(forKeys: [
				.fileSizeKey, .contentModificationDateKey,
			]),
			let rhsValues = try? rhs.resourceValues(forKeys: [
				.fileSizeKey, .contentModificationDateKey,
			])
		else {
			return false
		}
		return lhsValues.fileSize == rhsValues.fileSize
			&& lhsValues.contentModificationDate == rhsValues.contentModificationDate
	}
}
