// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Stable public identifiers for documented launcher failures.
enum SupportCode: String, CaseIterable, Codable, Sendable {
	case virga = "VIRGA"
	case pebble = "PEBBLE"
	case gabbro = "GABBRO"
	case basalt = "BASALT"
	case scree = "SCREE"
	case limpet = "LIMPET"
	case whelk = "WHELK"
	case sepia = "SEPIA"
	case anemone = "ANEMONE"
	case narwhal = "NARWHAL"
	case crux = "CRUX"

	var troubleshootingURL: URL {
		SupportLinks.documentationRoot.appending(
			path: "help/errors/\(rawValue.lowercased())/"
		)
	}

	static func hasValidSyntax(_ value: String) -> Bool {
		!value.isEmpty && value.allSatisfy { $0.isASCII && $0.isUppercase }
	}

	static func isPublished(_ value: String) -> Bool {
		SupportCode(rawValue: value) != nil
	}
}
