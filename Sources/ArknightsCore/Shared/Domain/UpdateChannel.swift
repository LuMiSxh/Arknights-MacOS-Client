// SPDX-License-Identifier: MPL-2.0

/// The published builds the launcher offers. Canary also offers prerelease builds that are still
/// soaking before promotion. Switching back to Stable never downgrades the installed launcher.
package enum UpdateChannel: String, CaseIterable, Sendable, Identifiable {
	case stable
	case canary

	package var id: String { rawValue }
}
