// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Decides which runtime lanes the host may run. x86 needs macOS 27 or earlier; ARM needs
/// macOS 26.0 or newer.
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
			return macOSVersion.majorVersion
				<= AppConstants.Runtime.x86LaneLastSupportedMacOSMajorVersion
		case .arm:
			return macOSVersion.majorVersion >= AppConstants.Runtime.armLaneMinimumMacOSMajorVersion
		}
	}

	/// The lane a fresh install uses when no selection is persisted. macOS 28 and later have no
	/// general Rosetta 2 support, so only the ARM64 lane can run there.
	package var defaultLane: RuntimeLane {
		allows(.x86) ? .x86 : .arm
	}
}
