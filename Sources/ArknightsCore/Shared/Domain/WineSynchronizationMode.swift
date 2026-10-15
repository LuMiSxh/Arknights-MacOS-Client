// SPDX-License-Identifier: MPL-2.0

package enum WineSynchronizationMode: String, CaseIterable, Codable, Sendable {
	case msync
	case esync

	package var displayName: String { rawValue.uppercased() }
}
