// SPDX-License-Identifier: MPL-2.0

import Foundation

extension WineRuntime {
	func applyBilibiliFontConfiguration(
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let key = "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes"
		try await applyRegistryEntries(
			["Microsoft YaHei", "Microsoft YaHei UI", "SimSun"].map {
				WineRegistryEntry(key: key, name: $0, kind: .string("Hiragino Sans GB W3"))
			},
			description: "Chinese font fallbacks",
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)
		try logHandle.write(
			contentsOf: Data(
				"Arknights Client: configured Bilibili Chinese font fallbacks.\n".utf8
			)
		)
	}

	func applyDisplayConfiguration(
		_ configuration: WineDisplayConfiguration,
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let current = configuration.registryState(in: prefixDirectory)
		let preciseScrollingValue = Self.normalizedScrollingRegistryData
		var entries: [WineRegistryEntry] = []
		if current?.retinaMode != configuration.registryValue {
			entries.append(
				WineRegistryEntry(
					key: Self.macDriverRegistryKey,
					name: "RetinaMode",
					kind: .string(configuration.registryValue)
				)
			)
		}
		if current?.logPixels != configuration.logPixels {
			entries.append(
				WineRegistryEntry(
					key: "HKCU\\Control Panel\\Desktop",
					name: "LogPixels",
					kind: .dword(UInt32(clamping: configuration.logPixels))
				)
			)
		}
		if current?.usePreciseScrolling != preciseScrollingValue {
			entries.append(
				WineRegistryEntry(
					key: Self.macDriverRegistryKey,
					name: Self.preciseScrollingRegistryValue,
					kind: .string(preciseScrollingValue)
				)
			)
		}
		guard !entries.isEmpty else { return }
		try await applyRegistryEntries(
			entries,
			description: "display configuration",
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)
		try? logHandle.write(
			contentsOf: Data(
				"Arknights Client: RetinaMode=\(configuration.registryValue); LogPixels=\(configuration.logPixels); UsePreciseScrolling=\(preciseScrollingValue).\n"
					.utf8
			)
		)
	}

	/// Whether the next launch would replay any prefix migration, so callers can
	/// show a "Migrating" state instead of the generic launch status.
	func hasPendingMigration(prefixDirectory: URL) throws -> Bool {
		try !migrationPlan(prefixDirectory: prefixDirectory).pending.isEmpty
	}

	private func migrationPlan(prefixDirectory: URL) throws -> RuntimeMigrationPlan {
		let fileManager = FileManager.default
		let systemRegistry = prefixDirectory.appending(path: "system.reg")
		let hasSystemRegistry = fileManager.fileExists(atPath: systemRegistry.path)
		let store = RuntimeMigrationStore(fileManager: fileManager)
		let persistedState = try store.load(from: prefixDirectory)
		let installedState: RuntimeMigrationState?
		if let persistedState {
			installedState = persistedState
		} else {
			installedState = try store.loadLegacy(
				from: prefixDirectory,
				expectedRevision: revision,
				hasSystemRegistry: hasSystemRegistry
			)
		}
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
		let persistedState = try store.load(from: prefixDirectory)
		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		let dxmtPayload = runtimeRoot.appending(path: "DXMT", directoryHint: .isDirectory)
		let dxmtCurrent = Self.dxmtIsCurrent(
			from: dxmtPayload,
			in: prefixDirectory,
			fileManager: fileManager
		)
		var plan = try migrationPlan(prefixDirectory: prefixDirectory)
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
					prefixDirectory: prefixDirectory,
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
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle
	) async throws {
		let globalKey = "HKCU\\Software\\Wine\\DllOverrides"
		let overrides = Self.globalRegistryOverrides.sorted { $0.key < $1.key }.map {
			WineRegistryEntry(key: globalKey, name: $0.key, kind: .string($0.value))
		}
		let commandKeyMapping = [
			Self.leftCommandIsCtrlRegistryValue, Self.rightCommandIsCtrlRegistryValue,
		].map {
			WineRegistryEntry(key: Self.macDriverRegistryKey, name: $0, kind: .string("y"))
		}
		try await applyRegistryEntries(
			overrides
				+ [
					WineRegistryEntry(
						key: Self.crashDialogRegistryKey,
						name: Self.crashDialogRegistryValue,
						kind: .dword(0)
					)
				]
				+ commandKeyMapping,
			description: "compatibility overrides",
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle
		)
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
