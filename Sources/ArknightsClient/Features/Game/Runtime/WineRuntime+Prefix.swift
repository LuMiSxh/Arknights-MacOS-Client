// SPDX-License-Identifier: MPL-2.0

import Foundation

extension WineRuntime {
	func applyDisplayConfiguration(
		_ configuration: WineDisplayConfiguration,
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let current = configuration.registryState(in: prefixDirectory)
		let preciseScrollingValue = Self.normalizedScrollingRegistryData
		if current?.retinaMode != configuration.registryValue {
			try await writeRegistryValue(
				key: "HKCU\\Software\\Wine\\Mac Driver",
				name: "RetinaMode",
				type: "REG_SZ",
				value: configuration.registryValue,
				environment: environment,
				logHandle: logHandle
			)
		}
		if current?.logPixels != configuration.logPixels {
			try await writeRegistryValue(
				key: "HKCU\\Control Panel\\Desktop",
				name: "LogPixels",
				type: "REG_DWORD",
				value: String(configuration.logPixels),
				environment: environment,
				logHandle: logHandle
			)
		}
		if current?.usePreciseScrolling != preciseScrollingValue {
			try await writeRegistryValue(
				key: Self.macDriverRegistryKey,
				name: Self.preciseScrollingRegistryValue,
				type: "REG_SZ",
				value: preciseScrollingValue,
				environment: environment,
				logHandle: logHandle
			)
		}
		guard
			current?.retinaMode != configuration.registryValue
				|| current?.logPixels != configuration.logPixels
				|| current?.usePreciseScrolling != preciseScrollingValue
		else { return }
		try? logHandle.write(
			contentsOf: Data(
				"Arknights Client: RetinaMode=\(configuration.registryValue); LogPixels=\(configuration.logPixels); UsePreciseScrolling=\(preciseScrollingValue).\n"
					.utf8
			)
		)
	}

	private func writeRegistryValue(
		key: String,
		name: String,
		type: String,
		value: String,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let status = try await runAndWait(
			executable: executableURL,
			arguments: [
				"reg.exe", "add", key, "/v", name, "/t", type, "/d", value, "/f",
			],
			environment: environment,
			output: logHandle
		)
		guard status == 0 else {
			throw LauncherError.runtimeConfiguration(
				"Wine could not configure \(name) (status \(status))."
			)
		}
	}

	/// Whether the next launch would replay any prefix migration, so callers can
	/// show a "Migrating" state instead of the generic launch status.
	func hasPendingMigration(prefixDirectory: URL) -> Bool {
		!migrationPlan(prefixDirectory: prefixDirectory).pending.isEmpty
	}

	private func migrationPlan(prefixDirectory: URL) -> RuntimeMigrationPlan {
		let fileManager = FileManager.default
		let systemRegistry = prefixDirectory.appending(path: "system.reg")
		let hasSystemRegistry = fileManager.fileExists(atPath: systemRegistry.path)
		let store = RuntimeMigrationStore(fileManager: fileManager)
		let persistedState = store.load(from: prefixDirectory)
		let installedState =
			persistedState
			?? store.loadLegacy(
				from: prefixDirectory,
				expectedRevision: revision,
				hasSystemRegistry: hasSystemRegistry
			)
		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		let dxmtPayload = runtimeRoot.appending(path: "DXMT", directoryHint: .isDirectory)
		let invalidatedMigrations: Set<RuntimeMigration> =
			Self.dxmtIsCurrent(
				from: dxmtPayload,
				in: prefixDirectory,
				fileManager: fileManager
			)
			? [] : [.installDXMT]
		return RuntimeMigrationPlan(
			expectedRevision: revision,
			installedState: installedState,
			hasSystemRegistry: hasSystemRegistry,
			invalidatedMigrations: invalidatedMigrations
		)
	}

	func preparePrefixIfNeeded(
		at prefixDirectory: URL,
		gameDirectory: URL,
		logsDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle,
		log: LauncherLog? = nil
	) async throws {
		let fileManager = FileManager.default
		let store = RuntimeMigrationStore(fileManager: fileManager)
		let persistedState = store.load(from: prefixDirectory)
		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		let dxmtPayload = runtimeRoot.appending(path: "DXMT", directoryHint: .isDirectory)
		let dxmtCurrent = Self.dxmtIsCurrent(
			from: dxmtPayload,
			in: prefixDirectory,
			fileManager: fileManager
		)
		var plan = migrationPlan(prefixDirectory: prefixDirectory)
		if !plan.pending.isEmpty {
			await log?.info(
				"Prefix migration plan: \(plan.pending); runtimeRevision=\(revision); "
					+ "persistedState=\(persistedState != nil); dxmtCurrent=\(dxmtCurrent)"
			)
		}
		for migration in plan.pending {
			let stepStarted = Date()
			await log?.debug("Running prefix migration: \(migration)")
			switch migration {
			case .initializeWinePrefix:
				try await initializePrefix(environment: environment, logHandle: logHandle)
			case .installDXMT:
				try Self.installDXMT(
					from: dxmtPayload,
					in: prefixDirectory,
					fileManager: fileManager
				)
			case .configureRegistry:
				try await configureCompatibilityOverrides(
					environment: environment,
					logHandle: logHandle
				)
			}
			plan.complete(migration)
			try store.save(plan.state, to: prefixDirectory)
			await log?.debug(
				"Completed prefix migration: \(migration); "
					+ "elapsed=\(String(format: "%.2fs", max(0, Date().timeIntervalSince(stepStarted))))"
			)
		}
		if plan.pending.isEmpty {
			if persistedState != plan.state {
				try store.save(plan.state, to: prefixDirectory)
			}
			await log?.debug("Prefix migration: nothing pending; runtimeRevision=\(revision)")
		} else {
			await log?.info("Prefix migration completed; ran \(plan.pending.count) step(s)")
		}
		try store.removeLegacyMarkers(from: prefixDirectory)
		try WinePrefixConfigurator().configure(
			prefixDirectory: prefixDirectory,
			gameDirectory: gameDirectory,
			logsDirectory: logsDirectory
		)
	}

	private func initializePrefix(
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
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
	}

	private func configureCompatibilityOverrides(
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
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
		for name in [Self.leftCommandIsCtrlRegistryValue, Self.rightCommandIsCtrlRegistryValue] {
			let status = try await runAndWait(
				executable: executableURL,
				arguments: [
					"reg.exe", "add", Self.macDriverRegistryKey,
					"/v", name,
					"/t", "REG_SZ", "/d", "y", "/f",
				],
				environment: environment,
				output: logHandle
			)
			guard status == 0 else {
				throw LauncherError.runtimeConfiguration(
					"Wine could not map the Command key to Control (status \(status))."
				)
			}
		}
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

	static func dxmtIsCurrent(
		from payloadDirectory: URL,
		in prefixDirectory: URL,
		fileManager: FileManager = .default
	) -> Bool {
		for (architecture, windowsDirectory) in [("x64", "system32"), ("x32", "syswow64")] {
			for library in dxmtLibraryNames {
				let source = payloadDirectory.appending(path: architecture).appending(path: library)
				let destination =
					prefixDirectory
					.appending(path: "drive_c/windows", directoryHint: .isDirectory)
					.appending(path: windowsDirectory, directoryHint: .isDirectory)
					.appending(path: library)
				guard filesMatch(source, destination, fileManager: fileManager) else {
					return false
				}
			}
		}
		return true
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
