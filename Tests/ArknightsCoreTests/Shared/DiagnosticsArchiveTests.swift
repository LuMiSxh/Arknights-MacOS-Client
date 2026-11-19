// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

struct DiagnosticsArchiveTests {
	private let redaction = DiagnosticsRedaction(homeDirectory: "/Users/tester", userName: "tester")

	/// The archive collects recent game and macOS text logs, redacts them, and leaves out
	/// databases, event logs, save data, old files, and other apps' crash reports.
	@Test(arguments: [
		(
			GameRegion.chinaBilibili,
			[
				"Logs/CrashSight/china-bilibili/CrashSight.1.log",
				"Logs/sdklogs/china-bilibili/BLPlatform64/BLWebBrowser/web.log",
				"Logs/sdklogs/china-bilibili/BLPlatform64/platform.log",
			]
		),
		(GameRegion.china, ["Logs/CrashSight/china/CrashSight.1.log"]),
		(GameRegion.global, ["Logs/CrashSight/global/CrashSight.1.log"]),
	])
	func archiveCollectsRedactedRecentTextFilesOnly(
		region: GameRegion, gameFiles: [String]
	)
		async throws
	{
		let temporary = try TemporaryDirectory("DiagnosticsArchiveTests")
		defer { temporary.remove() }
		let game = temporary.url.appending(path: "game", directoryHint: .isDirectory)
		let reports = temporary.url.appending(path: "reports", directoryHint: .isDirectory)
		let leaky = "open /Users/tester/x https://h.example/p?token=abc by tester\n"
		let now = Date()
		let old = now.addingTimeInterval(-AppConstants.Diagnostics.recentFileWindow - 60)
		for (path, modified) in [
			("CrashSightLog/CrashSight.1.log", now), ("CrashSightLog/CrashSight.0.log", old),
			("CrashSightLog/CrashSight.1.db", now),
			("BLPlatform64/platform.log", now), ("BLPlatform64/PLLog.db", now),
			("BLPlatform64/PCGamePlatform.exe", now), ("BLPlatform64/HGEventLog.log", now),
			("BLPlatform64/BLWebBrowser/web.log", now), ("HGEventLog_Encrypted/e.log", now),
			("mmkv/save.log", now), ("platform.log", now),
		] {
			try write(leaky, to: game.appending(path: path), modified: modified)
		}
		for (name, modified) in [
			("ArknightsClient-2026-11-19.ips", now), ("wine64-preloader-2026-11-19.ips", now),
			("Safari-2026-11-19.ips", now), ("ArknightsClient-2026-10-01.ips", old),
		] {
			try write(leaky, to: reports.appending(path: name), modified: modified)
		}
		let runtimePin = temporary.url.appending(path: "RUNTIME.json")
		try write("{}", to: runtimePin, modified: now)

		let archive = try await DiagnosticsArchive(
			logFiles: [], sdkLogDirectory: temporary.url.appending(path: "none"),
			publisher: region.publisher, environment: "{}\n",
			gameDirectories: [(region, game)], crashReportsDirectory: reports, now: now,
			readme: "# Readme", baseName: "Diagnostics", directory: temporary.url,
			redaction: redaction, log: LauncherLog(fileURL: temporary.url.appending(path: "l.log")),
			applicationSupportRoot: temporary.url, runtimeConfigurationURL: runtimePin
		).write()

		let extracted = temporary.url.appending(path: "extracted", directoryHint: .isDirectory)
		try extract(archive, into: extracted)
		let expected =
			(gameFiles + [
				"CrashReports/ArknightsClient-2026-11-19.ips",
				"CrashReports/wine64-preloader-2026-11-19.ips",
				"README.md", "RUNTIME.json", "environment.json",
			]).sorted()
		#expect(try files(under: extracted) == expected)
		for path in expected where path.hasSuffix(".log") || path.hasSuffix(".ips") {
			#expect(
				try String(contentsOf: extracted.appending(path: path), encoding: .utf8)
					== "open ~/x https://h.example/p by <user>\n")
		}
	}

	/// `environment.json` carries its schema number and human-formatted values.
	@Test
	func environmentJSONHasASchemaAndReadableValues() throws {
		let options = GameLaunchOptions(
			displayMode: .fullscreen, resolution: .hd,
			fullscreenResolution: .fixed(GameDisplaySize(width: 1600, height: 900)))
		let environment = DiagnosticsEnvironment(
			app: .init(version: "1.0.0", build: "1", location: "applications"),
			system: .init(
				macOS: "Version 15", chip: "Apple M1", memoryGB: 16, rosetta: "available",
				lowPowerMode: false, displays: []),
			runtime: .init(
				selectedLane: "arm", name: nil, installedVersions: [:],
				metalFXSpatialUpscaling: "unknown", pinnedPrefixRevision: nil, prefixMigrations: nil
			),
			game: .init(
				server: "chinaBilibili", installedVersion: nil, latestKnownVersion: nil,
				updateAvailable: false, installLocation: "managed",
				volume: .init(freeBytes: nil, fileSystem: nil), installState: nil,
				installedServers: []),
			settings: .init(options: options, usesHardwareCursor: true))

		let json = try environment.json()

		#expect(json.contains("\"schema\" : 1"))
		#expect(json.contains("\"fullscreenResolution\" : \"1600x900\""))
	}

	private func write(_ text: String, to url: URL, modified: Date) throws {
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data(text.utf8).write(to: url)
		try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
	}

	private func files(under directory: URL) throws -> [String] {
		let enumerator = try #require(
			FileManager.default.enumerator(
				at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
		let prefix = directory.resolvingSymlinksInPath().path + "/"
		return enumerator.compactMap { $0 as? URL }.compactMap { url in
			let resolved = url.resolvingSymlinksInPath()
			guard
				(try? resolved.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
			else { return nil }
			return String(resolved.path.dropFirst(prefix.count))
		}.sorted()
	}

	private func extract(_ archive: URL, into directory: URL) throws {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
		process.arguments = ["-x", "-k", archive.path, directory.path]
		try process.run()
		process.waitUntilExit()
		#expect(process.terminationStatus == 0)
	}
}
