// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension WineRuntime {
	func applyBilibiliFontConfiguration(
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle,
		spawnGate: WineProcessSpawnGate? = nil,
		log: LauncherLog? = nil
	) async throws {
		try await applyRegistryEntries(
			Self.bilibiliFontRegistryEntries(),
			description: "Chinese font fallbacks",
			prefixDirectory: prefixDirectory,
			environment: environment,
			logHandle: logHandle,
			spawnGate: spawnGate,
			log: log
		)
		try logHandle.write(
			contentsOf: Data(
				"Arknights Client: configured Bilibili Chinese font fallbacks.\n".utf8
			)
		)
	}

	static func bilibiliFontRegistryEntries() -> [WineRegistryEntry] {
		let gdiKey = "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes"
		let directWriteKey = "HKCU\\Software\\Wine\\Fonts\\Replacements"
		let gdiSubstitutions = ["Microsoft YaHei", "Microsoft YaHei UI", "SimSun"].map {
			WineRegistryEntry(key: gdiKey, name: $0, kind: .string("Hiragino Sans GB W3"))
		}
		let directWriteReplacements = [
			("Microsoft YaHei", "Hiragino Sans GB W3"),
			("MicrosoftYaHei-Bold", "Hiragino Sans GB W6"),
			("PingFangSC-Regular", "Hiragino Sans GB W3"),
			("Noto Sans CJK SC", "Hiragino Sans GB W3"),
			("Noto Sans CJK JP", "Hiragino Sans GB W3"),
		].map { name, replacement in
			WineRegistryEntry(key: directWriteKey, name: name, kind: .string(replacement))
		}
		return gdiSubstitutions + directWriteReplacements
	}

	func applyDisplayConfiguration(
		_ configuration: WineDisplayConfiguration,
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle,
		log: LauncherLog? = nil,
		spawnGate: WineProcessSpawnGate? = nil
	) async throws {
		let current = configuration.registryState(in: prefixDirectory, log: log)
		let preciseScrollingValue = Self.normalizedScrollingRegistryData
		var entries: [WineRegistryEntry] = []
		if current?.retinaMode != configuration.retinaEnabled {
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
		if current?.usePreciseScrolling != false {
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
			logHandle: logHandle,
			spawnGate: spawnGate,
			log: log
		)
		logHandle.appendLaunchLogLine(
			"Arknights Client: RetinaMode=\(configuration.registryValue); LogPixels=\(configuration.logPixels); UsePreciseScrolling=\(preciseScrollingValue).\n",
			log: log
		)
	}

	// Whether the next launch would replay any prefix migration, so callers can
	// show a "Migrating" state instead of the generic launch status.
	func hasPendingMigration(prefixDirectory: URL) throws -> Bool {
		try !migrationPlanContext(prefixDirectory: prefixDirectory).plan.pending.isEmpty
	}

	private struct MigrationPlanContext {
		let plan: RuntimeMigrationPlan
		let persistedState: RuntimeMigrationState?
		let dxmtPayload: URL
		let dxmtCurrent: Bool
	}

	// Reads the runtime's `wine.inf` mtime and the prefix's stamp file. Returns false when the
	// runtime has no `wine.inf`, so a runtime without one never replays the prefix update.
	private static func winePrefixUpdateIsStale(
		prefixDirectory: URL,
		runtimeRoot: URL,
		fileManager: FileManager
	) throws -> Bool {
		let wineInf = runtimeRoot.appending(path: WinePrefixUpdateStamp.wineInfRelativePath)
		guard fileManager.fileExists(atPath: wineInf.path),
			let modified = try wineInf.resourceValues(forKeys: [.contentModificationDateKey])
				.contentModificationDate
		else { return false }
		let stampURL = prefixDirectory.appending(path: WinePrefixUpdateStamp.fileName)
		let contents: String?
		if fileManager.fileExists(atPath: stampURL.path) {
			contents = String(decoding: try Data(contentsOf: stampURL), as: UTF8.self)
		} else {
			contents = nil
		}
		return WinePrefixUpdateStamp.isStale(
			contents: contents,
			wineInfModificationTime: Int(modified.timeIntervalSince1970)
		)
	}

	private func migrationPlanContext(prefixDirectory: URL) throws -> MigrationPlanContext {
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
		let dxmtPayload = runtimeRoot.appending(
			path: dxmtPayloadDirectory, directoryHint: .isDirectory)
		let dxmtCurrent = try Self.dxmtIsCurrent(
			from: dxmtPayload,
			in: prefixDirectory,
			fileManager: fileManager,
			destinations: dxmtPayloadDestinations,
			libraries: dxmtPayloadLibraries
		)
		var invalidatedMigrations: Set<RuntimeMigration> =
			dxmtCurrent ? [] : [.installDXMT]
		if try Self.winePrefixUpdateIsStale(
			prefixDirectory: prefixDirectory,
			runtimeRoot: runtimeRoot,
			fileManager: fileManager
		) {
			invalidatedMigrations.insert(.initializeWinePrefix)
		}
		let plan = RuntimeMigrationPlan(
			expectedRevision: revision,
			installedState: installedState,
			hasSystemRegistry: hasSystemRegistry,
			invalidatedMigrations: invalidatedMigrations
		)
		return MigrationPlanContext(
			plan: plan,
			persistedState: persistedState,
			dxmtPayload: dxmtPayload,
			dxmtCurrent: dxmtCurrent
		)
	}

	func preparePrefixIfNeeded(
		at prefixDirectory: URL,
		gameDirectory: URL,
		logsDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle,
		logURL: URL? = nil,
		log: LauncherLog? = nil,
		spawnGate: WineProcessSpawnGate? = nil
	) async throws {
		let fileManager = FileManager.default
		let store = RuntimeMigrationStore(fileManager: fileManager)
		let migrationContext = try migrationPlanContext(prefixDirectory: prefixDirectory)
		let persistedState = migrationContext.persistedState
		let dxmtPayload = migrationContext.dxmtPayload
		let dxmtCurrent = migrationContext.dxmtCurrent
		var plan = migrationContext.plan
		if !plan.pending.isEmpty {
			log?.info(
				.prefix, "migration-plan",
				[
					"pending": Set(plan.pending),
					"runtimeRevision": revision,
					"persistedState": persistedState != nil,
					"dxmtCurrent": dxmtCurrent,
				]
			)
		}
		for migration in plan.pending {
			// A yielding caller stops between steps; the persisted state then resumes the rest.
			try Task.checkCancellation()
			let stepStarted = Date()
			log?.debug(.prefix, "migration-step-started", ["step": migration])
			switch migration {
			case .initializeWinePrefix:
				try await initializePrefix(
					prefixDirectory: prefixDirectory,
					environment: environment,
					logHandle: logHandle,
					logURL: logURL,
					spawnGate: spawnGate,
					log: log
				)
			case .installDXMT:
				try Self.installDXMT(
					from: dxmtPayload,
					in: prefixDirectory,
					fileManager: fileManager,
					destinations: dxmtPayloadDestinations,
					libraries: dxmtPayloadLibraries
				)
			case .configureRegistry:
				let stepOffset = logURL.map { Self.runtimeLogOffset($0, log: log) }
				do {
					try await configureCompatibilityOverrides(
						prefixDirectory: prefixDirectory,
						environment: environment,
						log: log,
						logHandle: logHandle,
						spawnGate: spawnGate
					)
				} catch is CancellationError {
					throw CancellationError()
				} catch {
					let errors =
						logURL.map {
							Self.wineErrorsSince(stepOffset ?? 0, in: $0, log: log)
						} ?? []
					Self.logWineStepFailure(
						step: migration, status: nil, errors: errors, log: log)
					throw error
				}
			case .shareRuntimeLibraries:
				try await shareRuntimeLibraries(prefixDirectory: prefixDirectory, log: log)
			case .removeLegacy32BitLibraries:
				try await removeLegacy32BitLibraries(prefixDirectory: prefixDirectory, log: log)
			}
			plan.complete(migration)
			try store.save(plan.state, to: prefixDirectory)
			log?.debug(
				.prefix, "migration-step-completed",
				[
					"step": migration,
					"elapsed": Duration.seconds(max(0, Date().timeIntervalSince(stepStarted))),
				]
			)
		}
		if plan.pending.isEmpty {
			if persistedState != plan.state {
				try store.save(plan.state, to: prefixDirectory)
			}
			log?.debug(.prefix, "up-to-date", ["runtimeRevision": revision])
		} else {
			log?.info(.prefix, "migration-completed", ["steps": plan.pending.count])
		}
		try store.removeLegacyMarkers(from: prefixDirectory)
		try WinePrefixConfigurator().configure(
			prefixDirectory: prefixDirectory,
			gameDirectory: gameDirectory,
			logsDirectory: logsDirectory
		)
	}

	@concurrent
	private static func deduplicateRuntimeLibraries(
		prefixDirectory: URL,
		runtimeRoot: URL,
		libraries: [String],
		lane: RuntimeLane
	) async -> WinePrefixLibraryDeduplicator.Report {
		WinePrefixLibraryDeduplicator(excludingNames: Set(libraries))
			.deduplicate(prefixDirectory: prefixDirectory, runtimeRoot: runtimeRoot, lane: lane)
	}

	@concurrent
	private static func cleanLegacyLibraries(
		prefixDirectory: URL,
		runtimeRoot: URL,
		libraries: [String],
		lane: RuntimeLane
	) async -> WinePrefixLegacyLibraryCleaner.Report {
		WinePrefixLegacyLibraryCleaner(launcherInstalledNames: Set(libraries))
			.clean(prefixDirectory: prefixDirectory, runtimeRoot: runtimeRoot, lane: lane)
	}

	// Clones are APFS-only and best effort: any failure keeps Wine's copies and never blocks launch.
	private func shareRuntimeLibraries(prefixDirectory: URL, log: LauncherLog?) async throws {
		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		let report = await Self.deduplicateRuntimeLibraries(
			prefixDirectory: prefixDirectory,
			runtimeRoot: runtimeRoot,
			libraries: dxmtPayloadLibraries,
			lane: lane ?? .x86
		)
		try Task.checkCancellation()
		if let code = report.cloneUnsupportedCode {
			log?.info(
				.prefix, "library-share-skipped",
				["reason": "clone-unsupported", "errno": code])
		}
		for failure in report.failures {
			log?.warning(.prefix, "library-share-failed", ["path": failure])
		}
		log?.info(
			.prefix, "library-share",
			["cloned": report.clonedCount, "bytes": report.clonedBytes])
	}

	// Best effort: failures are logged and never block launch, but cancellation leaves the step pending.
	private func removeLegacy32BitLibraries(prefixDirectory: URL, log: LauncherLog?) async throws {
		let runtimeRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent()
		let report = await Self.cleanLegacyLibraries(
			prefixDirectory: prefixDirectory,
			runtimeRoot: runtimeRoot,
			libraries: dxmtPayloadLibraries,
			lane: lane ?? .x86
		)
		try Task.checkCancellation()
		if report.skipped {
			log?.info(
				.prefix, "legacy-library-cleanup-skipped",
				["reason": "i386-windows-present"])
			return
		}
		for failure in report.failures {
			log?.warning(.prefix, "legacy-library-cleanup-failed", ["path": failure])
		}
		log?.info(
			.prefix, "legacy-library-cleanup",
			["removed": report.removedCount, "bytes": report.removedBytes])
	}

	private func initializePrefix(
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle,
		logURL: URL?,
		spawnGate: WineProcessSpawnGate?,
		log: LauncherLog?
	) async throws {
		var winebootEnvironment = environment
		// wineboot always opens a wait dialog; without the mac driver it has no window to show.
		winebootEnvironment["WINEDLLOVERRIDES"] = [
			winebootEnvironment["WINEDLLOVERRIDES"], Self.winebootDLLOverride,
		].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ";")
		let stepOffset = logURL.map { Self.runtimeLogOffset($0, log: log) }
		let exitStatus = try await runAndWait(
			executable: executableURL,
			arguments: ["wineboot.exe", "-u"],
			environment: winebootEnvironment,
			output: logHandle,
			spawnGate: spawnGate
		)
		guard exitStatus == 0 else {
			let errors =
				logURL.map {
					Self.wineErrorsSince(stepOffset ?? 0, in: $0, log: log)
				} ?? []
			Self.logWineStepFailure(
				step: RuntimeMigration.initializeWinePrefix,
				status: exitStatus,
				errors: errors,
				log: log
			)
			throw GameRuntimeError.runtimeConfiguration(
				"Wine could not initialize its prefix (status \(exitStatus))."
			)
		}
		// End wineboot's headless desktop before the game runs under the mac driver.
		// The shared spawn gate stays open for the steps that follow.
		try await Task {
			try await stop(prefixDirectory: prefixDirectory, spawnGate: nil)
		}.value
	}

	private func configureCompatibilityOverrides(
		prefixDirectory: URL,
		environment: [String: String],
		log: LauncherLog?,
		logHandle: FileHandle,
		spawnGate: WineProcessSpawnGate?
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
			logHandle: logHandle,
			spawnGate: spawnGate,
			log: log
		)
	}

	static func installDXMT(
		from payloadDirectory: URL,
		in prefixDirectory: URL,
		fileManager: FileManager = .default,
		destinations: [DXMTDestination] = dxmtDestinations,
		libraries: [String] = dxmtLibraryNames
	) throws {
		let sources = destinations.flatMap { destination in
			libraries.map {
				payloadDirectory.appending(path: destination.architecture).appending(path: $0)
			}
		}
		guard sources.allSatisfy({ fileManager.fileExists(atPath: $0.path) }) else {
			throw GameRuntimeError.runtimeConfiguration("The bundled DXMT payload is incomplete.")
		}

		for destination in destinations {
			let destinationDirectory =
				prefixDirectory
				.appending(path: "drive_c/windows", directoryHint: .isDirectory)
				.appending(path: destination.windowsDirectory, directoryHint: .isDirectory)
			try fileManager.createDirectory(
				at: destinationDirectory,
				withIntermediateDirectories: true
			)
			for library in libraries {
				let source =
					payloadDirectory
					.appending(path: destination.architecture)
					.appending(path: library)
				let destination = destinationDirectory.appending(path: library)
				if fileManager.fileExists(atPath: destination.path) {
					if try filesMatch(source, destination) { continue }
					try fileManager.removeItem(at: destination)
				}
				try fileManager.copyItem(at: source, to: destination)
			}
		}
	}

	static func dxmtIsCurrent(
		from payloadDirectory: URL,
		in prefixDirectory: URL,
		fileManager: FileManager = .default,
		destinations: [DXMTDestination] = dxmtDestinations,
		libraries: [String] = dxmtLibraryNames
	) throws -> Bool {
		for destination in destinations {
			for library in libraries {
				let source =
					payloadDirectory
					.appending(path: destination.architecture)
					.appending(path: library)
				let destination =
					prefixDirectory
					.appending(path: "drive_c/windows", directoryHint: .isDirectory)
					.appending(path: destination.windowsDirectory, directoryHint: .isDirectory)
					.appending(path: library)
				guard fileManager.fileExists(atPath: destination.path),
					try filesMatch(source, destination)
				else {
					return false
				}
			}
		}
		return true
	}

	private static func filesMatch(_ lhs: URL, _ rhs: URL) throws -> Bool {
		let lhsValues = try lhs.resourceValues(forKeys: [
			.fileSizeKey, .contentModificationDateKey,
		])
		let rhsValues = try rhs.resourceValues(forKeys: [
			.fileSizeKey, .contentModificationDateKey,
		])
		return lhsValues.fileSize == rhsValues.fileSize
			&& lhsValues.contentModificationDate == rhsValues.contentModificationDate
	}

	/// The trailing `err:` lines Wine writes for a failed step, oldest first.
	static func wineErrorLines(
		in text: String,
		limit: Int = AppConstants.Logging.wineErrorLines
	) -> [String] {
		text.split(whereSeparator: { $0.isNewline })
			.filter { $0.contains("err:") }
			.suffix(limit)
			.map { String($0).trimmingCharacters(in: .whitespaces) }
	}

	/// Reads the runtime log bytes written since `offset`, bounded to the last 64 KiB, and
	/// returns their `err:` lines. A read failure omits the field instead of failing the launch.
	static func wineErrorsSince(
		_ offset: UInt64,
		in logURL: URL,
		maximumBytes: Int = AppConstants.Logging.wineStepTailBytes,
		log: LauncherLog?
	) -> [String] {
		let data: Data
		let start: UInt64
		do {
			let handle = try FileHandle(forReadingFrom: logURL)
			defer { handle.closeFile() }
			let size = try handle.seekToEnd()
			start = max(offset, size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0)
			try handle.seek(toOffset: start)
			data = try handle.read(upToCount: maximumBytes) ?? Data()
		} catch {
			log?.warning(.prefix, "step-log-read-failed", error: error)
			return []
		}
		var text = String(decoding: data, as: UTF8.self)
		if start > offset, let newline = text.firstIndex(of: "\n") {
			// The byte window cut the first line; drop it so only whole errors remain.
			text = String(text[text.index(after: newline)...])
		}
		return wineErrorLines(in: text)
	}

	/// The runtime log's size before a setup step, so its failure reads only that step's output.
	static func runtimeLogOffset(_ logURL: URL, log: LauncherLog?) -> UInt64 {
		do {
			let handle = try FileHandle(forReadingFrom: logURL)
			defer { handle.closeFile() }
			return try handle.seekToEnd()
		} catch {
			log?.warning(.prefix, "step-log-offset-failed", error: error)
			return 0
		}
	}

	static func logWineStepFailure(
		step: any LogValue,
		status: Int32?,
		errors: [String],
		log: LauncherLog?
	) {
		guard let log else { return }
		let errorText = errors.isEmpty ? nil : errors.joined(separator: " | ")
		switch (status, errorText) {
		case (.some(let status), .some(let errorText)):
			log.error(
				.prefix, "step-failed",
				["step": step, "exitStatus": status, "wineErrors": errorText])
		case (.some(let status), .none):
			log.error(.prefix, "step-failed", ["step": step, "exitStatus": status])
		case (.none, .some(let errorText)):
			log.error(.prefix, "step-failed", ["step": step, "wineErrors": errorText])
		case (.none, .none):
			log.error(.prefix, "step-failed", ["step": step])
		}
	}
}
