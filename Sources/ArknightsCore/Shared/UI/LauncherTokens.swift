// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Spacing, radius, layout, control, and type tokens. Colors and opacities stay in `LauncherVisuals`.
package enum LauncherTokens {
	package enum Spacing {
		package static let hairline: CGFloat = 1
		package static let compact: CGFloat = 4
		package static let control: CGFloat = 8
		package static let content: CGFloat = 12
		package static let panel: CGFloat = 16
		package static let section: CGFloat = 20
		package static let page: CGFloat = 24
	}

	package enum Layout {
		/// Shared by the Settings and Onboarding navigation rails.
		package static let railWidth: CGFloat = 192
	}

	package enum Radius {
		package static let control: CGFloat = 10
		package static let panel: CGFloat = 16
		static let hudPill: CGFloat = 22
		package static let modal: CGFloat = 24
		package static let railRow: CGFloat = 8
	}

	/// Button and field insets. Buttons and text fields share the standard horizontal and
	/// vertical padding.
	package enum ControlPadding {
		package static let horizontal: CGFloat = 12
		package static let vertical: CGFloat = 6
		package static let largeHorizontal: CGFloat = 16
		package static let segmentTrack: CGFloat = 4
		package static let segmentHorizontal: CGFloat = 10
		package static let segmentVertical: CGFloat = 4
	}

	package enum Control {
		package static let borderWidth: CGFloat = 1
		static let focusWidth: CGFloat = 2
		static let standardHorizontalPadding: CGFloat = 12
		static let standardVerticalPadding: CGFloat = 6
		/// Capsule buttons and menu fields grow together, so both read one table.
		static func horizontalPadding(for controlSize: ControlSize) -> CGFloat {
			switch controlSize {
			case .mini, .small: 8
			case .large, .extraLarge: 16
			default: standardHorizontalPadding
			}
		}

		static func verticalPadding(for controlSize: ControlSize) -> CGFloat {
			switch controlSize {
			case .mini, .small: 4
			case .large, .extraLarge: 8
			default: standardVerticalPadding
			}
		}

		package static let hudHorizontalPadding: CGFloat = 12
		package static let hudVerticalPadding: CGFloat = 6
		static let iconButtonSize: CGFloat = 36
		static let iconButtonGlyphSize: CGFloat = 17
		/// Matches GlassCapsuleMenu: a 16 pt chevron chip plus 2 x 6 pt padding.
		static let fieldHeight: CGFloat = 28
	}

	package enum Typography {
		package static let pageTitle = Font.system(size: 22, weight: .medium)
		package static let sectionLabel = Font.system(size: 13, weight: .medium)
		package static let control = Font.system(size: 12, weight: .medium)
		package static let statusTitle = Font.system(size: 14, weight: .medium)
		package static let statusPercent = Font.system(size: 16, weight: .medium)
		package static let completionLabel = Font.system(size: 15, weight: .medium)
		package static let hudControlGlyph = Font.system(size: 13, weight: .medium)
		package static let hudProminentGlyph = Font.system(size: 16, weight: .medium)
		static let menuChevron = Font.system(size: 9, weight: .semibold)
		package static let tagGlyph = Font.system(size: 10, weight: .medium)
		package static let fallbackWordmark = Font.system(size: 440, weight: .regular)
		package static let wordmark = Font.system(.title, design: .serif)
	}
}
