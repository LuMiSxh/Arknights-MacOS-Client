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
		/// Height of the fade behind the Settings floating footer.
		package static let settingsFooterFade: CGFloat = 94
		/// Square app icon in the About settings header.
		package static let aboutIconSize: CGFloat = 76
		/// Width of the bundled document sheet.
		package static let documentModalWidth: CGFloat = 760
		/// Height of the bundled document sheet.
		package static let documentModalHeight: CGFloat = 600
		/// Failure sheet size without a support code.
		package static let failureSheetWidth: CGFloat = 620
		package static let failureSheetHeight: CGFloat = 432
		/// Failure sheet size with a support code.
		package static let failureSheetWidthWithCode: CGFloat = 720
		package static let failureSheetHeightWithCode: CGFloat = 600
		/// Width of a navigation rail row's leading icon.
		static let railIconWidth: CGFloat = 20
		static let railSelectionTickWidth: CGFloat = 3
		static let railSelectionTickHeight: CGFloat = 14
		static let railSelectionTickLeading: CGFloat = 2
		/// Accent length of the rule under a settings page header.
		static let sectionAccentRuleWidth: CGFloat = 72
		static let sectionAccentRuleHeight: CGFloat = 3
		/// Fixed width of the selected-region checkmark in the status HUD pill.
		package static let hudCheckmarkWidth: CGFloat = 16
		/// Horizontal inset of an expanded HUD pill's header.
		static let hudExpandedHorizontalPadding: CGFloat = 14
	}

	package enum Radius {
		package static let control: CGFloat = 10
		package static let panel: CGFloat = 16
		static let hudPill: CGFloat = 22
		package static let modal: CGFloat = 24
		package static let railRow: CGFloat = 8
		/// Default corner radius for the modal surface kind.
		static let glassModal: CGFloat = 20
		/// Default corner radius for the grouped surface kind.
		static let glassGroup: CGFloat = 12
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
		/// Vertical inset inside a settings panel row.
		static let settingsRowVertical: CGFloat = 10
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
		package static let iconButtonSize: CGFloat = 36
		package static let iconButtonGlyphSize: CGFloat = 17
		/// Matches GlassCapsuleMenu at the default control size: a 16 pt chevron chip plus 2 x 6 pt padding.
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
