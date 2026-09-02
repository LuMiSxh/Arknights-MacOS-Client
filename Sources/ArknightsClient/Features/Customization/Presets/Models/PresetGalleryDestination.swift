// SPDX-License-Identifier: MPL-2.0

import Foundation

enum PresetGalleryDestination: String, Identifiable {
	case artwork
	case operatorIcons

	var id: String { rawValue }

	var title: LocalizedStringResource {
		switch self {
		case .artwork: CustomizationStrings.artworkTitle
		case .operatorIcons: CustomizationStrings.operatorTitle
		}
	}

	var subtitle: LocalizedStringResource {
		switch self {
		case .artwork:
			CustomizationStrings.artworkSubtitle
		case .operatorIcons:
			CustomizationStrings.operatorSubtitle
		}
	}

	var searchPlaceholder: LocalizedStringResource {
		switch self {
		case .artwork: CustomizationStrings.artworkSearchPlaceholder
		case .operatorIcons: CustomizationStrings.operatorSearchPlaceholder
		}
	}

	var loadingText: LocalizedStringResource {
		switch self {
		case .artwork: CustomizationStrings.artworkLoading
		case .operatorIcons: CustomizationStrings.operatorLoading
		}
	}

	var emptyText: LocalizedStringResource {
		switch self {
		case .artwork: CustomizationStrings.artworkEmpty
		case .operatorIcons: CustomizationStrings.operatorEmpty
		}
	}
}
