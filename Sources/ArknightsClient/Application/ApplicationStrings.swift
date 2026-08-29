// SPDX-License-Identifier: MPL-2.0

import Foundation

enum ApplicationStrings {
	static let settings = LocalizedStringResource.applicationDockSettings

	static func play(_ region: String) -> LocalizedStringResource {
		.applicationDockPlay(region)
	}
}
