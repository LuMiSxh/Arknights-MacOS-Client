// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Decides which runtime lanes the host may run and which one the launcher uses. x86 needs
/// macOS 27 or earlier; ARM needs `AppConstants.Runtime.armLaneMinimumMacOS` or newer.
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
			let minimum = AppConstants.Runtime.armLaneMinimumMacOS
			return (macOSVersion.majorVersion, macOSVersion.minorVersion, macOSVersion.patchVersion)
				>= (minimum.majorVersion, minimum.minorVersion, minimum.patchVersion)
		}
	}

	/// The lane the launcher uses unless the user overrides it. ARM64 is preferred wherever it runs.
	package var defaultLane: RuntimeLane {
		allows(.arm) ? .arm : .x86
	}
}
