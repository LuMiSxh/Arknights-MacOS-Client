// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

struct DiagnosticsArchiveTests {
	private let redaction = DiagnosticsRedaction(homeDirectory: "/Users/tester", userName: "tester")

	/// The archive collects recent game and macOS text logs, redacts them, and leaves out
	/// databases, event logs, save data, oversized and old files, linked folders, and the crash
	/// reports of other apps. `environment.json` carries no home path.
	@Test(arguments: [
		(
			GameRegion.chinaBilibili, false,
			[
				"Logs/CrashSight/china-bilibili/CrashSight.1.log",
				"Logs/sdklogs/china-bilibili/BLPlatform64/BLWebBrowser/web.log",
				"Logs/sdklogs/china-bilibili/BLPlatform64/platform.log",
			]
		),
		(
			GameRegion.chinaBilibili, true,
			[
				"Logs/CrashSight/china-bilibili/CrashSight.1.log",
				"Logs/sdklogs/china-bilibili/BLPlatform64/platform.log",
			]
		),
		(GameRegion.china, false, ["Logs/CrashSight/china/CrashSight.1.log"]),
		(GameRegion.global, false, ["Logs/CrashSight/global/CrashSight.1.log"]),
	])
	func archiveCollectsRedactedRecentTextFilesOnly(
		region: GameRegion, linksWebBrowser: Bool, gameFiles: [String]
	) async throws {
		let temporary = try TemporaryDirectory("DiagnosticsArchiveTests")
		defer { temporary.remove() }
		let support = temporary.url.appending(path: "support", directoryHint: .isDirectory)
		let game = support.appending(path: "Games/game", directoryHint: .isDirectory)
		let reports = temporary.url.appending(path: "reports", directoryHint: .isDirectory)
		let outside = temporary.url.appending(path: "outside", directoryHint: .isDirectory)
		let leaky = "open /Users/tester/x https://h.example/p?token=abc by tester\n"
		let now = Date()
		let old = now.addingTimeInterval(-AppConstants.Diagnostics.recentFileWindow - 60)
		for (path, modified) in [
			("CrashSightLog/CrashSight.1.log", now), ("CrashSightLog/CrashSight.0.log", old),
			("CrashSightLog/CrashSight.1.db", now),
			("BLPlatform64/platform.log", now), ("BLPlatform64/PLLog.db", now),
			("BLPlatform64/PCGamePlatform.exe", now), ("BLPlatform64/HGEventLog.log", now),
			("HGEventLog_Encrypted/e.log", now), ("mmkv/save.log", now), ("platform.log", now),
		] {
			try write(leaky, to: game.appending(path: path), modified: modified)
		}
		let webBrowser = game.appending(
			path: "BLPlatform64/BLWebBrowser", directoryHint: .isDirectory)
		if linksWebBrowser {
			try write(leaky, to: outside.appending(path: "web.log"), modified: now)
			try FileManager.default.createSymbolicLink(at: webBrowser, withDestinationURL: outside)
		} else {
			try write(leaky, to: webBrowser.appending(path: "web.log"), modified: now)
		}
		try write(
			leaky + String(repeating: "x", count: AppConstants.Diagnostics.recentFileMaximumBytes),
			to: game.appending(path: "BLPlatform64/big.log"), modified: now)
		let wine = game.appending(path: "wine64-preloader").path
		for (name, process, modified) in [
			("wine64-preloader-1.ips", wine, now),
			("QtWebEngineProcess-1.ips", "/Applications/Other.app/QtWebEngineProcess", now),
			("wine64-preloader-0.ips", wine, old),
		] {
			let report =
				"{\"app_name\":\"x\"}\n{\"procPath\":\"\(process)\",\"note\":\"\(leaky.dropLast())\"}\n"
			try write(report, to: reports.appending(path: name), modified: modified)
		}
		let runtimePin = temporary.url.appending(path: "RUNTIME.json")
		try write("{}", to: runtimePin, modified: now)

		let archive = try await DiagnosticsArchive(
			logFiles: [temporary.url.appending(path: "vanished.log")],
			sdkLogDirectory: temporary.url.appending(path: "none"),
			publisher: region.publisher, environment: "{\"leak\":\"/Users/tester/x\"}\n",
			gameDirectories: [(region, game)], crashReportsDirectory: reports, now: now,
			readme: "# Readme", baseName: "Diagnostics", directory: temporary.url,
			redaction: redaction, log: LauncherLog(fileURL: temporary.url.appending(path: "l.log")),
			applicationSupportRoot: support, runtimeConfigurationURL: runtimePin
		).write()

		let extracted = temporary.url.appending(path: "extracted", directoryHint: .isDirectory)
		try extract(archive, into: extracted)
		let expected =
			(gameFiles + [
				"CrashReports/wine64-preloader-1.ips", "README.md", "RUNTIME.json",
				"environment.json",
			]).sorted()
		#expect(try files(under: extracted) == expected)
		for path in expected where path != "README.md" && path != "RUNTIME.json" {
			let text = try String(contentsOf: extracted.appending(path: path), encoding: .utf8)
			#expect(!text.contains("/Users/tester") && !text.contains("token=abc"))
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
