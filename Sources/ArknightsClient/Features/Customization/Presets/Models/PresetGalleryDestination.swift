// SPDX-License-Identifier: MPL-2.0

import Foundation

enum PresetGalleryDestination: String, Identifiable, Sendable {
	case artwork
	case operatorIcons

	var id: String { rawValue }

	var title: String {
		switch self {
		case .artwork: CustomizationStrings.artworkTitle
		case .operatorIcons: CustomizationStrings.operatorTitle
		}
	}

	var subtitle: String {
		switch self {
		case .artwork:
			CustomizationStrings.artworkSubtitle
		case .operatorIcons:
			CustomizationStrings.operatorSubtitle
		}
	}

	var searchPlaceholder: String {
		switch self {
		case .artwork: CustomizationStrings.artworkSearchPlaceholder
		case .operatorIcons: CustomizationStrings.operatorSearchPlaceholder
		}
	}

	var loadingText: String {
		switch self {
		case .artwork: CustomizationStrings.artworkLoading
		case .operatorIcons: CustomizationStrings.operatorLoading
		}
	}

	var emptyText: String {
		switch self {
		case .artwork: CustomizationStrings.artworkEmpty
		case .operatorIcons: CustomizationStrings.operatorEmpty
		}
	}
}
