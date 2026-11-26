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

	/// Why `lane` may or may not run on this host, for the startup lane-access log.
	package enum LaneAccessReason: String, Sendable {
		case ok
		case macOSBelowMinimum = "macos-below-minimum"
		case macOSAboveMaximum = "macos-above-maximum"
	}

	package func accessReason(for lane: RuntimeLane) -> LaneAccessReason {
		switch lane {
		case .x86:
			let lastSupported = AppConstants.Runtime.x86LaneLastSupportedMacOSMajorVersion
			return macOSVersion.majorVersion <= lastSupported ? .ok : .macOSAboveMaximum
		case .arm:
			let minimum = AppConstants.Runtime.armLaneMinimumMacOS
			let meetsMinimum =
				(macOSVersion.majorVersion, macOSVersion.minorVersion, macOSVersion.patchVersion)
				>= (minimum.majorVersion, minimum.minorVersion, minimum.patchVersion)
			return meetsMinimum ? .ok : .macOSBelowMinimum
		}
	}

	package func allows(_ lane: RuntimeLane) -> Bool {
		accessReason(for: lane) == .ok
	}

	/// The lane the launcher uses unless the user overrides it. ARM64 is preferred wherever it runs.
	package var defaultLane: RuntimeLane {
		allows(.arm) ? .arm : .x86
	}
}
