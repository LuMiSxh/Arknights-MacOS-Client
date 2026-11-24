// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

/// The validated `delta.json` of a runtime delta (delta schema 1): the complete target tree and,
/// for each file, how to produce it from the installed runtime.
struct RuntimeDeltaPlan: Sendable {
	enum FileAction: Sendable, Equatable {
		case keep(sourceSHA256: String)
		case patch(sourceSHA256: String, data: [String])
		case add(data: [String])
	}

	enum Node: Sendable, Equatable {
		case directory
		case symlink(target: String)
		case file(executable: Bool, size: Int, sha256: String, action: FileAction)
	}

	struct Item: Sendable, Equatable {
		let components: [String]
		let node: Node

		var path: String { components.joined(separator: "/") }
	}

	static let supportedSchemaVersion = 1
	static let manifestName = "delta.json"

	let items: [Item]

	/// The bytes of every patched and added file, which the apply step writes to disk.
	var targetBytes: Int64 {
		items.reduce(into: 0) { total, item in
			guard case .file(_, let size, _, let action) = item.node else { return }
			if case .keep = action { return }
			total += Int64(size)
		}
	}

	/// Reads and validates `delta.json` from an extracted `Delta/` directory.
	static func load(
		deltaRoot: URL, lane: RuntimeLane, from: String, to: String
	) throws -> RuntimeDeltaPlan {
		let data = try BoundedFileReader.readRegularFile(
			at: deltaRoot.appending(path: manifestName),
			maximumBytes: AppConstants.Runtime.deltaManifestMaximumBytes)
		let document: Document
		do {
			document = try JSONDecoder().decode(Document.self, from: data)
		} catch {
			throw RuntimeDeltaError.invalidManifest("delta.json is malformed: \(error)")
		}
		let architecture = lane == .arm ? "arm64" : "x86_64"
		guard document.schemaVersion == supportedSchemaVersion, document.arch == architecture,
			document.from == from, document.to == to
		else {
			throw RuntimeDeltaError.invalidManifest("delta.json does not describe this upgrade")
		}
		return try RuntimeDeltaPlan(items: validated(document.entries))
	}

	// MARK: - Validation

	private static func validated(_ entries: [Document.Entry]) throws -> [Item] {
		var items: [Item] = []
		var directories: Set<String> = [""]
		var seen = Set<String>()
		for entry in entries {
			guard RuntimeConfiguration.isSafeRelativePath(entry.path), entry.path != "RUNTIME.json",
				seen.insert(entry.path).inserted
			else {
				throw RuntimeDeltaError.unsafePath(entry.path)
			}
			let components = entry.path.split(separator: "/").map(String.init)
			let parent = components.dropLast().joined(separator: "/")
			guard directories.contains(parent) else {
				throw RuntimeDeltaError.invalidManifest(
					"\(entry.path) has no directory entry above it")
			}
			let node: Node
			switch entry.type {
			case .directory:
				directories.insert(entry.path)
				node = .directory
			case .symlink:
				guard let target = entry.target, !target.isEmpty else {
					throw RuntimeDeltaError.invalidManifest("\(entry.path) has no link target")
				}
				do {
					try RuntimeArchive.validateLinkTarget(
						target, sourceDirectory: components.dropLast())
				} catch {
					throw RuntimeDeltaError.unsafePath(entry.path)
				}
				node = .symlink(target: target)
			case .file:
				node = try fileNode(entry)
			}
			items.append(Item(components: components, node: node))
		}
		return items
	}

	private static func fileNode(_ entry: Document.Entry) throws -> Node {
		guard let executable = entry.executable, let size = entry.size, let sha256 = entry.sha256,
			let operation = entry.op, size >= 0, RuntimeConfiguration.isSHA256(sha256),
			operation == .keep || size <= AppConstants.Runtime.deltaFileMaximumBytes
		else {
			throw RuntimeDeltaError.invalidManifest("\(entry.path) is not a complete file entry")
		}
		let action: FileAction
		switch operation {
		case .keep:
			// A kept file is the installed file, so both hashes must name the same content.
			guard let source = entry.sourceSha256, source == sha256 else {
				throw RuntimeDeltaError.invalidManifest("\(entry.path) is not a valid keep")
			}
			action = .keep(sourceSHA256: source)
		case .patch:
			guard let source = entry.sourceSha256, RuntimeConfiguration.isSHA256(source),
				let data = try dataComponents(entry)
			else {
				throw RuntimeDeltaError.invalidManifest("\(entry.path) is not a valid patch")
			}
			action = .patch(sourceSHA256: source, data: data)
		case .add:
			guard let data = try dataComponents(entry) else {
				throw RuntimeDeltaError.invalidManifest("\(entry.path) is not a valid add")
			}
			action = .add(data: data)
		}
		return .file(executable: executable, size: size, sha256: sha256, action: action)
	}

	private static func dataComponents(_ entry: Document.Entry) throws -> [String]? {
		guard let data = entry.data else { return nil }
		guard RuntimeConfiguration.isSafeRelativePath(data) else {
			throw RuntimeDeltaError.unsafePath(data)
		}
		return data.split(separator: "/").map(String.init)
	}

	// MARK: - Document

	struct Document: Decodable {
		enum EntryType: String, Decodable { case directory, symlink, file }
		enum Operation: String, Decodable { case keep, patch, add }

		struct Entry: Decodable {
			let path: String
			let type: EntryType
			let target: String?
			let executable: Bool?
			let size: Int?
			let sha256: String?
			let op: Operation?
			let sourceSha256: String?
			let data: String?
		}

		let schemaVersion: Int
		let arch: String
		let from: String
		let to: String
		let entries: [Entry]
	}
}
