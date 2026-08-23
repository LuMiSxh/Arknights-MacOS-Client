// SPDX-License-Identifier: MPL-2.0

import Foundation

enum L10n {
	static func string(
		_ resource: LocalizedStringResource,
		locale: Locale? = nil
	) -> String {
		var resource = resource
		if let locale { resource.locale = locale }
		return String(localized: resource)
	}
}
