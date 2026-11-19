// SPDX-License-Identifier: MPL-2.0

/// When a daily reset reminder fires, relative to the 04:00 server reset.
package enum ResetReminderTiming: String, CaseIterable, Sendable {
	case off
	case atReset
	case minutes15
	case minutes30
	case minutes60
	case minutes120

	/// Minutes before the reset that the reminder fires, or `nil` when reminders are off.
	package var leadMinutes: Int? {
		switch self {
		case .off: nil
		case .atReset: 0
		case .minutes15: 15
		case .minutes30: 30
		case .minutes60: 60
		case .minutes120: 120
		}
	}
}
