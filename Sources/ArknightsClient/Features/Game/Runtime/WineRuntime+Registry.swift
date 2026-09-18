// SPDX-License-Identifier: MPL-2.0

import Foundation

/// One `HKEY\Path` → `name` = `value` assignment destined for the prefix registry.
struct WineRegistryEntry {
	enum Kind {
		case string(String)
		/// Written as `dword:`-prefixed hex, the only numeric form `.reg` files accept.
		case dword(UInt32)
	}

	let key: String
	let name: String
	let kind: Kind
}

extension WineRuntime {
	/// Applies every entry with one `regedit.exe`, instead of a Windows process per `reg.exe
	/// add`. The script lives inside the prefix because `regedit.exe` takes only Windows paths,
	/// and is removed afterwards.
	func applyRegistryEntries(
		_ entries: [WineRegistryEntry],
		description: String,
		prefixDirectory: URL,
		environment: [String: String],
		logHandle: FileHandle,
		fileManager: FileManager = .default
	) async throws {
		guard !entries.isEmpty else { return }

		let scriptDirectory = prefixDirectory.appending(
			path: "drive_c/windows/temp",
			directoryHint: .isDirectory
		)
		let scriptURL = scriptDirectory.appending(path: Self.registryScriptName)
		try fileManager.createDirectory(at: scriptDirectory, withIntermediateDirectories: true)
		// A byte-order mark selects UTF-16LE, keeping the Chinese font substitutions intact.
		var script = Data([0xFF, 0xFE])
		script.append(
			contentsOf: Array(Self.registryScript(for: entries).utf16).flatMap {
				[UInt8($0 & 0xFF), UInt8($0 >> 8)]
			})
		try script.write(to: scriptURL, options: .atomic)
		defer { try? fileManager.removeItem(at: scriptURL) }

		let status = try await runAndWait(
			executable: executableURL,
			arguments: ["regedit.exe", "/S", "C:\\windows\\temp\\" + Self.registryScriptName],
			environment: environment,
			output: logHandle
		)
		guard status == 0 else {
			throw LauncherError.runtimeConfiguration(
				"Wine could not apply the \(description) (status \(status))."
			)
		}
	}

	static func registryScript(for entries: [WineRegistryEntry]) -> String {
		var lines = ["Windows Registry Editor Version 5.00"]
		// Grouped by key so each section header appears once, in the order keys first occur.
		var keyOrder: [String] = []
		var entriesByKey: [String: [WineRegistryEntry]] = [:]
		for entry in entries {
			if entriesByKey[entry.key] == nil { keyOrder.append(entry.key) }
			entriesByKey[entry.key, default: []].append(entry)
		}
		for key in keyOrder {
			lines.append("")
			lines.append("[\(expandedRootKey(in: key))]")
			for entry in entriesByKey[key] ?? [] {
				let value: String
				switch entry.kind {
				case .string(let text): value = "\"\(escapedRegistryText(text))\""
				case .dword(let number): value = String(format: "dword:%08x", number)
				}
				lines.append("\"\(escapedRegistryText(entry.name))\"=\(value)")
			}
		}
		return lines.joined(separator: "\r\n") + "\r\n"
	}

	/// `.reg` sections need the long root-key names; `reg.exe` accepted the short aliases.
	private static func expandedRootKey(in key: String) -> String {
		for (alias, expanded) in [
			("HKCU\\", "HKEY_CURRENT_USER\\"),
			("HKLM\\", "HKEY_LOCAL_MACHINE\\"),
			("HKCR\\", "HKEY_CLASSES_ROOT\\"),
			("HKU\\", "HKEY_USERS\\"),
		] where key.hasPrefix(alias) {
			return expanded + key.dropFirst(alias.count)
		}
		return key
	}

	private static func escapedRegistryText(_ value: String) -> String {
		value
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
	}

	static let registryScriptName = "arknights-client-overrides.reg"
}
