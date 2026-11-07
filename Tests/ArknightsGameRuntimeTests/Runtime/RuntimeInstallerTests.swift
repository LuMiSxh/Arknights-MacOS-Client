// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import CryptoKit
import Foundation
import Testing

@testable import ArknightsGameRuntime

// A plain tar builder so installer tests do not need downloaded fixtures.
private struct TarBuilder {
	private(set) var data = Data()

	mutating func append(
		name: String,
		typeFlag: UInt8 = 0x30,
		linkName: String = "",
		mode: Int = 0o644,
		content: Data = Data()
	) {
		var header = [UInt8](repeating: 0, count: 512)
		writeString(name, into: &header, range: 0..<100)
		writeOctal(mode, into: &header, range: 100..<108)
		writeOctal(content.count, into: &header, range: 124..<136)
		header[156] = typeFlag
		writeString(linkName, into: &header, range: 157..<257)
		data.append(contentsOf: header)
		data.append(content)
		let padding = (512 - (content.count % 512)) % 512
		if padding > 0 { data.append(Data(repeating: 0, count: padding)) }
	}

	mutating func directory(_ name: String) {
		append(name: name, typeFlag: 0x35)
	}

	mutating func finish() {
		data.append(Data(repeating: 0, count: 1_024))
	}

	private func writeString(_ value: String, into header: inout [UInt8], range: Range<Int>) {
		for (index, byte) in Array(value.utf8).enumerated() where index < range.count {
			header[range.lowerBound + index] = byte
		}
	}

	private func writeOctal(_ value: Int, into header: inout [UInt8], range: Range<Int>) {
		for (index, byte) in Array(String(value, radix: 8).utf8).enumerated()
		where index < range.count {
			header[range.lowerBound + index] = byte
		}
	}
}

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

private func makeInstaller(paths: AppPaths, route: StubURLProtocol.Route) -> RuntimeInstaller {
	RuntimeInstaller(
		paths: paths,
		access: RuntimeAccess(
			macOSVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
		),
		session: route.session
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

		let manifest = try JSONDecoder().decode(
			RuntimeManifest.self,
			from: Data(contentsOf: installed.directory.appending(path: "RUNTIME.json")))
		#expect(manifest.architecture == .x86)
		#expect(manifest.prefixRevision == 2)
		#expect(manifest.runtime.sha256 == sha256Hex(archive))
		#expect(manifest.interface.features.hardwareCursor)
	}

	@Test
	func reinstallingThePinnedVersionReplacesTheLaneTree() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerReinstall")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let route = StubURLProtocol.Route()
		route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), archive)
		}
		let paths = makePaths(temporary)
		let installer = makeInstaller(paths: paths, route: route)
		let pin = makePin(archive: archive)

		let first = try await installer.install(pin: pin) { _ in }
		try Data("stale".utf8).write(to: first.directory.appending(path: "bin/wine64"))

		let second = try await installer.install(pin: pin) { _ in }

		#expect(second.directory == first.directory)
		#expect(
			try Data(contentsOf: second.directory.appending(path: "bin/wine64"))
				== Data("wine64".utf8))
		#expect(route.requestCount == 1)
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
		let part = paths.runtimeDownloadsDirectory.appending(path: "\(pin.sha256).part")
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
				makeHTTPResponse(url: request.url!, status: 206),
				Data(suffix)
			)
		}
		let paths = makePaths(temporary)
		try FileManager.default.createDirectory(
			at: paths.runtimeDownloadsDirectory, withIntermediateDirectories: true)
		try Data(prefix).write(
			to: paths.runtimeDownloadsDirectory.appending(path: "\(pin.sha256).part"))
		let installer = makeInstaller(paths: paths, route: route)

		let installed = try await installer.install(pin: pin) { _ in }

		#expect(installed.version == "1.0.0")
		#expect(route.requestCount == 1)
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

	@Test
	func verifyAcceptsAnExactSizeAndHash() throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerVerify")
		defer { temporary.remove() }
		let archive = runtimeArchive()
		let archiveURL = temporary.url.appending(path: "runtime.tar")
		try archive.write(to: archiveURL)
		let paths = makePaths(temporary)
		let installer = RuntimeInstaller(paths: paths)

		#expect(throws: Never.self) {
			try installer.verify(pin: makePin(archive: archive), archiveAt: archiveURL)
		}
	}
}
