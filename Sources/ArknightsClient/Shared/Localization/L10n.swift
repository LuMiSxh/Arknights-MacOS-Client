// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

enum L10n {
	private static let localeOverride = Mutex<Locale?>(nil)

	static func useAppLanguage(_ language: AppLanguage) {
		localeOverride.withLock { $0 = language.locale }
	}

	static func string(
		_ resource: LocalizedStringResource,
		locale: Locale? = nil
	) -> String {
		var resource = resource
		if let locale = locale ?? localeOverride.withLock({ $0 }) {
			resource.locale = locale
		}
		return String(localized: resource)
	}
}
