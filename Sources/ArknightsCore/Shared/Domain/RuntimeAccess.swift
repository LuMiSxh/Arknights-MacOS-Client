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

	/// The lane a fresh install uses when no selection is persisted. ARM64 is the recommended lane
	/// wherever it runs. macOS 15 can only run x86_64.
	package var defaultLane: RuntimeLane {
		allows(.arm) ? .arm : .x86
	}
}
