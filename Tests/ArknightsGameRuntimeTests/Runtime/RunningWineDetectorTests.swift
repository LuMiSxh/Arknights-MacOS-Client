// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

private struct WineDetectorFixture {
	let temporary: TemporaryDirectory
	let paths: AppPaths
	let bundleURL: URL

	init(_ label: String) throws {
		temporary = try TemporaryDirectory(label)
		paths = AppPaths(
			applicationSupportDirectory: temporary.url.appending(
				path: "Support", directoryHint: .isDirectory),
			cachesDirectory: temporary.url.appending(
				path: "Caches", directoryHint: .isDirectory),
			libraryDirectory: temporary.url.appending(
				path: "Library", directoryHint: .isDirectory),
			runtimeSelection: RuntimeSelection(override: .x86)
		)
		bundleURL = temporary.url.appending(
			path: "Arknights Client.app", directoryHint: .isDirectory)
	}
}

@Test
func detectsProcessesInsideTheBundleAndRuntimeRoot() async throws {
	let fixture = try WineDetectorFixture("RunningWineDetectorMatchTests")
	defer { fixture.temporary.remove() }
	let runtimeExecutable = fixture.paths.runtimeRoot
		.appending(path: "x86-1.0.0/bin/wine64")
	try FileManager.default.createDirectory(
		at: runtimeExecutable.deletingLastPathComponent(), withIntermediateDirectories: true)
	try Data().write(to: runtimeExecutable)
	let runtimeProcess = runtimeExecutable.path
	let bundledExecutable = fixture.bundleURL
		.appending(path: "Contents/Resources/Runtime/bin/wine64")
	try FileManager.default.createDirectory(
		at: bundledExecutable.deletingLastPathComponent(), withIntermediateDirectories: true)
	let bundledProcess = bundledExecutable.path
	let alias = fixture.temporary.url.appending(
		path: "runtime-alias", directoryHint: .isDirectory)
	try FileManager.default.createSymbolicLink(
		at: alias, withDestinationURL: fixture.paths.runtimeRoot)
	let aliasedProcess = alias.appending(path: "x86-1.0.0/bin/wine64").path

	for path in [runtimeProcess, bundledProcess, aliasedProcess] {
		let detector = RunningWineDetector(
			paths: fixture.paths,
			bundleURL: fixture.bundleURL,
			processPaths: { [(pid: Int32(4242), path: path)] }
		)
		#expect(await detector.isRunning(), "\(path)")
	}
}

@Test
func ignoresSiblingPrefixesAndTheLauncherProcess() async throws {
	let fixture = try WineDetectorFixture("RunningWineDetectorRejectTests")
	defer { fixture.temporary.remove() }
	let ownProcessPath = fixture.bundleURL
		.appending(path: "Contents/MacOS/ArknightsClient").path
	let siblingRuntime = fixture.paths.runtimeRoot.path + "-sibling/bin/wine64"
	let siblingBundle = fixture.bundleURL.path + ".old/Contents/MacOS/wine64"
	// Sparkle and a second launcher instance live inside the bundle but are not Wine.
	let sparkleUpdater = fixture.bundleURL
		.appending(path: "Contents/Frameworks/Sparkle.framework/Autoupdate").path
	let secondLauncher = fixture.bundleURL
		.appending(path: "Contents/Resources/Helpers/ArknightsClient").path
	let detector = RunningWineDetector(
		paths: fixture.paths,
		bundleURL: fixture.bundleURL,
		processPaths: {
			[
				(pid: ProcessInfo.processInfo.processIdentifier, path: ownProcessPath),
				(pid: Int32(4242), path: siblingRuntime),
				(pid: Int32(4243), path: siblingBundle),
				(pid: Int32(4244), path: sparkleUpdater),
				(pid: Int32(4245), path: secondLauncher),
			]
		}
	)

	#expect(await detector.isRunning() == false)
}
