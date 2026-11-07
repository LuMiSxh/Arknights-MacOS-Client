// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Decides which runtime lanes the host may run. x86 is always allowed; ARM needs macOS 26.0
/// or newer.
package struct RuntimeAccess: Sendable {
	package let macOSVersion: OperatingSystemVersion

	package init(
		macOSVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
	) {
		self.macOSVersion = macOSVersion
	}

	package func allows(_ lane: RuntimeLane) -> Bool {
		switch lane {
		case .x86:
			return true
		case .arm:
			return macOSVersion.majorVersion >= 26
		}
	}
}
