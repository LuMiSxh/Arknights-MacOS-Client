// SPDX-License-Identifier: MPL-2.0

import Foundation

extension OperatingSystemVersion {
	/// The version as the app shows it, omitting a zero minor version.
	package var macOSDisplayName: String {
		minorVersion == 0
			? "macOS \(majorVersion)"
			: "macOS \(majorVersion).\(minorVersion)"
	}
}
