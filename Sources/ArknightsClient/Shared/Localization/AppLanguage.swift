// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
	case system
	case english
	case german

	var id: String { rawValue }

	var locale: Locale? {
		switch self {
		case .system: nil
		case .english: Locale(identifier: "en")
		case .german: Locale(identifier: "de")
		}
	}
}
