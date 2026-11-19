// SPDX-License-Identifier: MPL-2.0

/// The game's installation presence for the selected server. Exactly one state holds at a time.
package enum InstallPresence: Equatable, Sendable {
	case installed(version: String)
	case partialDownload
	case absent

	package var isInstalled: Bool {
		if case .installed = self { true } else { false }
	}

	package var installedVersion: String? {
		if case .installed(let version) = self { version } else { nil }
	}
}
