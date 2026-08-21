// SPDX-License-Identifier: MPL-2.0

import Foundation

struct InstalledState: Codable, Sendable {
	let version: String
	let basis: String
	let source: String
	let installedAt: Date
	let files: [ManifestFile]?
}
