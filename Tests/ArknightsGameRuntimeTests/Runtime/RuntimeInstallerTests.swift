// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import CryptoKit
import Foundation
import Synchronization
import Testing

@testable import ArknightsGameRuntime

private func runtimeArchive() -> Data {
	var builder = TarBuilder()
	builder.directory("Libraries")
	builder.directory("Libraries/Wine")
	builder.directory("Libraries/Wine/bin")
	builder.append(
		name: "Libraries/Wine/bin/wine64", mode: 0o755, content: Data("wine64".utf8))
	builder.append(
		name: "Libraries/Wine/bin/wineserver", mode: 0o755, content: Data("wineserver".utf8))
	builder.append(
		name: "Libraries/Wine/bin/Arknights", typeFlag: 0x32, linkName: "wine64")
	builder.directory("Libraries/Wine/lib/wine/x86_64-unix")
	builder.append(
		name: "Libraries/Wine/lib/wine/x86_64-unix/winemac.so",
		content: Data("winemac".utf8))
	builder.append(
		name: "Libraries/Wine/lib/wine/x86_64-unix/winecoreaudio.so",
		content: Data("audio".utf8))
	builder.append(
		name: "Libraries/Wine/lib/wine/x86_64-windows/winemetal.dll",
		content: Data("winemetal".utf8))
	builder.append(
		name: "Libraries/DXMT/x64/d3d11.dll", content: Data("dxmt".utf8))
	builder.append(name: "NOTICE.md", content: Data("notice".utf8))
	builder.append(name: "Licenses/MIT.txt", content: Data("mit".utf8))
	builder.finish()
	return builder.data
}

private func sha256Hex(_ data: Data) -> String {
	SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func makePin(
	archive: Data,
	sha256: String? = nil,
	version: String = "1.0.0",
	name: String = "Test Runtime"
) -> PinnedRuntime {
	PinnedRuntime(
		lane: .x86,
		name: name,
		version: version,
		url: URL(string: "https://download.test/runtime.tar"),
		sha256: sha256 ?? sha256Hex(archive),
		sizeBytes: archive.count,
		minimumMacOS: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0),
		prefixRevision: 2,
		interface: RuntimeManifest.Interface(
			archive: .init(wineDirectory: "Wine", dxmtDirectory: "DXMT"),
			executables: ["bin/wine64", "bin/wineserver"],
			features: RuntimeFeatures(
				hardwareCursor: true,
				metalFXSpatialUpscaling: false,
				nativeFullscreenSpace: false
			),
			requiredFiles: [
				"lib/wine/x86_64-unix/winemac.so",
				"lib/wine/x86_64-unix/winecoreaudio.so",
				"lib/wine/x86_64-windows/winemetal.dll",
			],
			macDriver: "lib/wine/x86_64-unix/winemac.so",
			launcher: .init(path: "bin/Arknights", target: "wine64"),
			dxmt: .init(
				payloadDirectory: "DXMT",
				destinations: ["x64": "system32"],
				libraries: ["d3d11.dll"]
			)
		),
		components: RuntimeManifest.Components(wine: "11.17", dxmt: "0.80", moltenvk: nil),
		provenance: nil
	)
}

private func makePaths(_ temporary: TemporaryDirectory) -> AppPaths {
	AppPaths(
		applicationSupportDirectory: temporary.url,
		runtimeSelection: RuntimeSelection(selected: .x86)
	)
}

private func makeInstaller(
	paths: AppPaths,
	route: StubURLProtocol.Route,
	clock: any Clock<Duration> = ContinuousClock()
) -> RuntimeInstaller {
	RuntimeInstaller(
		paths: paths,
		selectionStore: RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile),
		access: RuntimeAccess(
			macOSVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
		),
		session: route.session,
		clock: clock
	)
}

struct RuntimeInstallerTests {
	@Test
	func installsThePinnedRuntimeAndRemovesTheOldLaneVersion() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerInstall")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let route = StubURLProtocol.Route()
		route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), archive)
		}
		let paths = makePaths(temporary)
		let installer = makeInstaller(paths: paths, route: route)
		let oldVersion = paths.runtimeVersionDirectory(for: .x86, version: "0.9.0")
		try FileManager.default.createDirectory(at: oldVersion, withIntermediateDirectories: true)

		let legacyPart = paths.runtimeDownloadsDirectory.appending(path: "old.part")
		let laneDownloads = paths.runtimeDownloadsDirectory(for: .x86)
		let otherLanePart = paths.runtimeDownloadsDirectory(for: .arm).appending(path: "x.part")
		try FileManager.default.createDirectory(
			at: otherLanePart.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data("legacy".utf8).write(to: legacyPart)
		try Data("arm".utf8).write(to: otherLanePart)

		let installed = try await installer.install(pin: makePin(archive: archive)) { _ in }

		#expect(installed.lane == .x86)
		#expect(installed.version == "1.0.0")
		#expect(
			FileManager.default.isExecutableFile(
				atPath: installed.directory.appending(path: "bin/wine64").path))
		#expect(
			FileManager.default.fileExists(
				atPath: installed.directory.appending(path: "DXMT/x64/d3d11.dll").path))
		#expect(
			FileManager.default.fileExists(
				atPath: installed.directory.appending(path: "NOTICE.md").path))
		#expect(
			FileManager.default.fileExists(
				atPath: installed.directory.appending(path: "Licenses/MIT.txt").path))
		#expect(
			(try FileManager.default.destinationOfSymbolicLink(
				atPath: installed.directory.appending(path: "bin/Arknights").path)) == "wine64")
		#expect(!FileManager.default.fileExists(atPath: oldVersion.path))
		#expect(!FileManager.default.fileExists(atPath: laneDownloads.path))
		#expect(!FileManager.default.fileExists(atPath: legacyPart.path))
		#expect(FileManager.default.fileExists(atPath: otherLanePart.path))

		let manifest = try JSONDecoder().decode(
			RuntimeManifest.self,
			from: Data(contentsOf: installed.directory.appending(path: "RUNTIME.json")))
		#expect(manifest.architecture == .x86)
		#expect(manifest.prefixRevision == 2)
		#expect(manifest.runtime.sha256 == sha256Hex(archive))
		#expect(manifest.interface.features.hardwareCursor)
	}

	@Test
	func rejectsAnArchiveWithTheWrongHashAndDeletesThePart() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerHash")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let route = StubURLProtocol.Route()
		route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), archive)
		}
		let paths = makePaths(temporary)
		let installer = makeInstaller(paths: paths, route: route)
		let pin = makePin(archive: archive, sha256: String(repeating: "0", count: 64))

		await #expect(throws: RuntimeInstallError.hashMismatch) {
			try await installer.install(pin: pin) { _ in }
		}
		let laneDownloads = paths.runtimeDownloadsDirectory(for: pin.lane)
		let part = laneDownloads.appending(path: "\(pin.sha256).part")
		#expect(!FileManager.default.fileExists(atPath: part.path))
	}

	@Test
	func resumesAPartialDownloadWithARangeRequest() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerResume")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let split = archive.count / 2
		let prefix = archive.prefix(split)
		let suffix = archive.suffix(from: split)
		let pin = makePin(archive: archive)
		let route = StubURLProtocol.Route()
		route.handler = { request in
			#expect(request.value(forHTTPHeaderField: "Range") == "bytes=\(split)-")
			return (
				makeHTTPResponse(
					url: request.url!, status: 206,
					headers: [
						"Content-Range": "bytes \(split)-\(archive.count - 1)/\(archive.count)"
					]),
				Data(suffix)
			)
		}
		let paths = makePaths(temporary)
		try FileManager.default.createDirectory(
			at: paths.runtimeDownloadsDirectory(for: .x86), withIntermediateDirectories: true)
		try Data(prefix).write(
			to: paths.runtimeDownloadsDirectory(for: .x86).appending(path: "\(pin.sha256).part"))
		let installer = makeInstaller(paths: paths, route: route)

		let installed = try await installer.install(pin: pin) { _ in }

		#expect(installed.version == "1.0.0")
		#expect(route.requestCount == 1)
	}

	@Test
	func aRedirectDowngradingToHTTPIsRejected() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerRedirect")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let route = StubURLProtocol.Route()
		route.redirectURL = URL(string: "http://download.test/runtime.tar")!
		route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), archive)
		}
		let installer = makeInstaller(paths: makePaths(temporary), route: route)

		var failure: RuntimeInstallError?
		do {
			_ = try await installer.install(pin: makePin(archive: archive)) { _ in }
		} catch {
			failure = error as? RuntimeInstallError
		}

		guard case .downloadFailed(let detail) = failure else {
			Issue.record("expected a download failure, got \(String(describing: failure))")
			return
		}
		#expect(detail.contains("redirectRejected"))
		#expect(route.requestCount == 1)
	}

	@Test
	func aDownloadThatReceivesNothingReportsAStall() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerStall")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let stalled = DispatchSemaphore(value: 0)
		let route = StubURLProtocol.Route()
		route.handler = { request in
			// Holds the response until the ticker has reported the stall. The bound only
			// prevents a hang when the stall is never reported.
			_ = stalled.wait(timeout: .now() + .seconds(30))
			return (makeHTTPResponse(url: request.url!, status: 200), archive)
		}
		// The recording clock advances by each requested sleep, so the ticker ages the download
		// without real waiting.
		let installer = makeInstaller(
			paths: makePaths(temporary), route: route, clock: RecordingClock())

		let sawStall = Mutex(false)
		_ = try await installer.install(pin: makePin(archive: archive)) { progress in
			guard progress.phase == .downloading, progress.isTransferStalled else { return }
			sawStall.withLock { $0 = true }
			stalled.signal()
		}

		#expect(sawStall.withLock { $0 })
	}

	@Test
	func aFailedInstallLeavesTheOldLaneVersionInPlace() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerFailure")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let route = StubURLProtocol.Route()
		route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), archive)
		}
		let paths = makePaths(temporary)
		let installer = makeInstaller(paths: paths, route: route)
		let oldVersion = paths.runtimeVersionDirectory(for: .x86, version: "0.9.0")
		try FileManager.default.createDirectory(at: oldVersion, withIntermediateDirectories: true)
		let pin = makePin(archive: archive, sha256: String(repeating: "0", count: 64))

		await #expect(throws: RuntimeInstallError.hashMismatch) {
			try await installer.install(pin: pin) { _ in }
		}
		#expect(FileManager.default.fileExists(atPath: oldVersion.path))
		#expect(paths.installedRuntimeVersion(for: .x86) == nil)
	}
}
