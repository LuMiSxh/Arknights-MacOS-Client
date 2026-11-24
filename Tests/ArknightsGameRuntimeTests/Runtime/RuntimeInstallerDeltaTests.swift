// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsRuntimeTestSupport
import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsGameRuntime

private enum Node {
	case directory(String)
	case file(String, String, executable: Bool)
	case link(String, String)

	var path: String {
		switch self {
		case .directory(let path), .file(let path, _, _), .link(let path, _): path
		}
	}
}

private let installedTree: [Node] = [
	.directory("bin"),
	.file("bin/wine64", "wine64", executable: true),
	.file("bin/wineserver", "wineserver-v1", executable: true),
	.link("bin/Arknights", "wine64"),
	.directory("lib"),
	.file("lib/obsolete.txt", "old", executable: false),
	.directory("lib/wine"),
	.directory("lib/wine/x86_64-unix"),
	.file("lib/wine/x86_64-unix/winecoreaudio.so", "audio", executable: false),
	.file("lib/wine/x86_64-unix/winemac.so", "winemac-v1", executable: false),
	.directory("lib/wine/x86_64-windows"),
	.file("lib/wine/x86_64-windows/winemetal.dll", "winemetal", executable: false),
	.directory("old"),
	.file("old/file", "gone", executable: false),
	.directory("share"),
	.file("share/run.sh", "echo", executable: false),
	.file("NOTICE.md", "notice", executable: false),
]

private let pinnedTree: [Node] = [
	.directory("DXMT"),
	.directory("DXMT/x64"),
	.file("DXMT/x64/d3d11.dll", "dxmt-v2", executable: false),
	.directory("bin"),
	.file("bin/wine64", "wine64", executable: true),
	.file("bin/wineserver", "wineserver-v2-patched", executable: true),
	.link("bin/Arknights", "wine64"),
	.link("bin/wine", "wine64"),
	.directory("lib"),
	.directory("lib/wine"),
	.directory("lib/wine/x86_64-unix"),
	.file("lib/wine/x86_64-unix/winecoreaudio.so", "audio", executable: false),
	.file("lib/wine/x86_64-unix/winemac.so", "winemac-v2", executable: false),
	.directory("lib/wine/x86_64-windows"),
	.file("lib/wine/x86_64-windows/winemetal.dll", "winemetal", executable: false),
	.directory("share"),
	.file("share/run.sh", "echo", executable: true),
	.file("NOTICE.md", "notice", executable: false),
]

private let expectedSnapshot: [String: String] = [
	"DXMT": "dir",
	"DXMT/x64": "dir",
	"DXMT/x64/d3d11.dll": "file:dxmt-v2",
	"NOTICE.md": "file:notice",
	"bin": "dir",
	"bin/Arknights": "link:wine64",
	"bin/wine": "link:wine64",
	"bin/wine64": "file:wine64:x",
	"bin/wineserver": "file:wineserver-v2-patched:x",
	"lib": "dir",
	"lib/wine": "dir",
	"lib/wine/x86_64-unix": "dir",
	"lib/wine/x86_64-unix/winecoreaudio.so": "file:audio",
	"lib/wine/x86_64-unix/winemac.so": "file:winemac-v2",
	"lib/wine/x86_64-windows": "dir",
	"lib/wine/x86_64-windows/winemetal.dll": "file:winemetal",
	"share": "dir",
	"share/run.sh": "file:echo:x",
]

private func writeTree(_ nodes: [Node], at root: URL) throws {
	let fileManager = FileManager.default
	for node in nodes {
		let url = root.appending(path: node.path)
		switch node {
		case .directory:
			try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
		case .file(_, let content, let executable):
			try Data(content.utf8).write(to: url)
			try fileManager.setAttributes(
				[.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: url.path)
		case .link(_, let target):
			try fileManager.createSymbolicLink(atPath: url.path, withDestinationPath: target)
		}
	}
}

private func fullArchive(_ nodes: [Node]) -> Data {
	var builder = TarBuilder()
	builder.directory("Runtime")
	for node in nodes {
		let name = "Runtime/" + node.path
		switch node {
		case .directory: builder.directory(name)
		case .file(_, let content, let executable):
			builder.append(
				name: name, mode: executable ? 0o755 : 0o644, content: Data(content.utf8))
		case .link(_, let target): builder.append(name: name, typeFlag: 0x32, linkName: target)
		}
	}
	builder.finish()
	return xzCompressed(builder.data)
}

/// A one-control bsdiff patch: add the byte-wise difference over the shared length, then the rest as extra.
private func makePatch(old: Data, new: Data) -> Data {
	func le(_ value: Int) -> [UInt8] {
		withUnsafeBytes(of: Int64(value).littleEndian) { Array($0) }
	}
	let shared = min(old.count, new.count)
	let diff = (0..<shared).map { new[new.startIndex + $0] &- old[old.startIndex + $0] }
	let extra = Array(new.suffix(new.count - shared))
	var patch = Array("RTBSDF01".utf8) + le(new.count) + le(1)
	patch += le(shared) + le(extra.count) + le(0)
	return Data(patch + diff + extra)
}

/// The `delta.json` entries and data files that turn `installedTree` into `pinnedTree`.
private func deltaContents() -> (entries: [[String: Any]], data: [String: Data]) {
	var entries: [[String: Any]] = []
	var data: [String: Data] = [:]
	for node in pinnedTree {
		switch node {
		case .directory(let path):
			entries.append(["path": path, "type": "directory"])
		case .link(let path, let target):
			entries.append(["path": path, "type": "symlink", "target": target])
		case .file(let path, let content, let executable):
			let new = Data(content.utf8)
			var entry: [String: Any] = [
				"path": path, "type": "file", "executable": executable, "size": new.count,
				"sha256": sha256Hex(new),
			]
			let old = installedTree.compactMap { candidate -> Data? in
				guard case .file(path, let oldContent, _) = candidate else { return nil }
				return Data(oldContent.utf8)
			}.first
			if let old, old == new {
				entry["op"] = "keep"
				entry["sourceSha256"] = sha256Hex(old)
			} else if let old {
				entry["op"] = "patch"
				entry["sourceSha256"] = sha256Hex(old)
				entry["data"] = "data/\(data.count)"
				data["data/\(data.count)"] = makePatch(old: old, new: new)
			} else {
				entry["op"] = "add"
				entry["data"] = "data/\(data.count)"
				data["data/\(data.count)"] = new
			}
			entries.append(entry)
		}
	}
	return (entries, data)
}

private func deltaArchive(entries: [[String: Any]], data: [String: Data]) throws -> Data {
	let manifest = try JSONSerialization.data(
		withJSONObject: [
			"schemaVersion": 1, "arch": "x86_64", "from": "0.9.0", "to": "1.0.0",
			"entries": entries,
		] as [String: Any], options: [.sortedKeys])
	var builder = TarBuilder()
	builder.directory("Delta")
	builder.directory("Delta/data")
	builder.append(name: "Delta/delta.json", content: manifest)
	for (name, content) in data.sorted(by: { $0.key < $1.key }) {
		builder.append(name: "Delta/" + name, content: content)
	}
	builder.finish()
	return xzCompressed(builder.data)
}

private func snapshot(of root: URL) throws -> [String: String] {
	var result: [String: String] = [:]
	let fileManager = FileManager.default
	for relative in try fileManager.subpathsOfDirectory(atPath: root.path)
	where relative != "RUNTIME.json" {
		let path = root.appending(path: relative).path
		let attributes = try fileManager.attributesOfItem(atPath: path)
		switch attributes[.type] as? FileAttributeType {
		case .typeDirectory:
			result[relative] = "dir"
		case .typeSymbolicLink:
			result[relative] = "link:" + (try fileManager.destinationOfSymbolicLink(atPath: path))
		default:
			let content = String(decoding: try Data(contentsOf: URL(filePath: path)), as: UTF8.self)
			let permissions = attributes[.posixPermissions] as? Int ?? 0
			result[relative] = "file:" + content + (permissions & 0o111 != 0 ? ":x" : "")
		}
	}
	return result
}

private enum DeltaFailure: CaseIterable, CustomTestStringConvertible {
	case tamperedInstalledFile
	case wrongResultHash
	case escapingPath
	case absolutePath
	case symlinkedParentEntry
	case escapingLinkTarget
	case installedParentIsSymlink

	var testDescription: String { String(describing: self) }
}

struct RuntimeInstallerDeltaTests {
	private struct Outcome {
		let installed: InstalledRuntime
		let requests: [String]
		let outsideDirectory: URL
	}

	/// Installs the pinned tree over the installed one, offering `delta` and the full archive.
	private func install(
		in temporary: TemporaryDirectory, failure: DeltaFailure?
	) async throws -> Outcome {
		let paths = makeInstallerPaths(temporary)
		try makeInstalledRuntime(version: "0.9.0", lane: .x86, paths: paths)
		let installedRoot = paths.runtimeVersionDirectory(for: .x86, version: "0.9.0")
		try writeTree(installedTree, at: installedRoot)
		let outside = temporary.url.appending(path: "outside", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

		var (entries, data) = deltaContents()
		let extra: [String: Any] = [
			"type": "file", "executable": false, "size": 1, "sha256": sha256Hex(Data("x".utf8)),
			"op": "add", "data": "data/99",
		]
		switch failure {
		case nil: break
		case .tamperedInstalledFile:
			try Data("tampered".utf8).write(to: installedRoot.appending(path: "bin/wineserver"))
		case .wrongResultHash:
			let index = entries.firstIndex { $0["path"] as? String == "bin/wineserver" }!
			entries[index]["sha256"] = String(repeating: "0", count: 64)
		case .escapingPath, .absolutePath:
			data["data/99"] = Data("x".utf8)
			entries.append(
				extra.merging(["path": failure == .escapingPath ? "../evil" : "/evil"]) { $1 })
		case .symlinkedParentEntry:
			data["data/99"] = Data("x".utf8)
			entries.append(["path": "link", "type": "symlink", "target": "bin"])
			entries.append(extra.merging(["path": "link/evil"]) { $1 })
		case .escapingLinkTarget:
			entries.append(["path": "bin/evil", "type": "symlink", "target": "../../outside"])
		case .installedParentIsSymlink:
			try Data("echo".utf8).write(to: outside.appending(path: "run.sh"))
			try FileManager.default.removeItem(at: installedRoot.appending(path: "share"))
			try FileManager.default.createSymbolicLink(
				at: installedRoot.appending(path: "share"), withDestinationURL: outside)
		}

		let full = fullArchive(pinnedTree)
		let delta = try deltaArchive(entries: entries, data: data)
		let pin = makePin(
			archive: full,
			deltas: [
				PinnedRuntimeDelta(
					from: "0.9.0",
					asset: RuntimeAsset(
						url: URL(string: "https://download.test/delta.tar.xz")!,
						sha256: sha256Hex(delta), sizeBytes: delta.count))
			])
		let requested = Mutex<[String]>([])
		let route = StubURLProtocol.Route()
		route.handler = { request in
			let name = request.url!.lastPathComponent
			requested.withLock { $0.append(name) }
			return (
				makeHTTPResponse(url: request.url!, status: 200),
				name == "delta.tar.xz" ? delta : full
			)
		}
		let installed = try await makeInstaller(paths: paths, route: route)
			.install(pin: pin) { _ in }
		return Outcome(
			installed: installed, requests: requested.withLock { $0 }, outsideDirectory: outside)
	}

	@Test
	func aDeltaUpgradesTheInstalledRuntimeWithoutTheFullArchive() async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerDelta")
		defer { temporary.remove() }

		let outcome = try await install(in: temporary, failure: nil)

		#expect(outcome.requests == ["delta.tar.xz"])
		#expect(try snapshot(of: outcome.installed.directory) == expectedSnapshot)
		let paths = makeInstallerPaths(temporary)
		#expect(paths.installedRuntimeVersion(for: .x86) == "1.0.0")
		#expect(
			!FileManager.default.fileExists(
				atPath: paths.runtimeVersionDirectory(for: .x86, version: "0.9.0").path))
		let manifest = try JSONDecoder().decode(
			RuntimeManifest.self,
			from: Data(contentsOf: outcome.installed.directory.appending(path: "RUNTIME.json")))
		#expect(manifest.runtime.sha256 == sha256Hex(fullArchive(pinnedTree)))
	}

	@Test(arguments: DeltaFailure.allCases)
	private func aFailedDeltaFallsBackToTheFullArchive(failure: DeltaFailure) async throws {
		let temporary = try TemporaryDirectory("RuntimeInstallerDeltaFallback")
		defer { temporary.remove() }

		let outcome = try await install(in: temporary, failure: failure)

		#expect(outcome.requests == ["delta.tar.xz", "runtime.tar.xz"])
		#expect(try snapshot(of: outcome.installed.directory) == expectedSnapshot)
		#expect(
			!FileManager.default.fileExists(atPath: temporary.url.appending(path: "evil").path))
		let outside = try FileManager.default.contentsOfDirectory(
			atPath: outcome.outsideDirectory.path)
		if failure == .installedParentIsSymlink {
			#expect(outside == ["run.sh"])
			#expect(
				!FileManager.default.isExecutableFile(
					atPath: outcome.outsideDirectory.appending(path: "run.sh").path))
		} else {
			#expect(outside.isEmpty)
		}
	}
}
