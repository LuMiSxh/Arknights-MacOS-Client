// SPDX-License-Identifier: MPL-2.0

enum WineSynchronizationMode: String, CaseIterable, Codable, Sendable {
	case msync
	case esync

	var displayName: String { rawValue.uppercased() }
}
