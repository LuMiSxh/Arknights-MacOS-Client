// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Layout and type tokens from the approved design lab. Values that already exist in
/// `LauncherVisuals` forward to it, so the two stay in step.
package enum LauncherTokens {
	package enum Spacing {
		package static let compact = LauncherVisuals.Spacing.compact
		package static let control = LauncherVisuals.Spacing.control
		package static let content = LauncherVisuals.Spacing.content
		package static let panel = LauncherVisuals.Spacing.panel
	}

	package enum Radius {
		/// The window sheet.
		package static let sheet = LauncherVisuals.Radius.modal
		/// The modal dialog card.
		package static let modal: CGFloat = 20
		package static let group: CGFloat = 12
		package static let field: CGFloat = 8
		package static let railRow: CGFloat = 8
	}

	/// Button and field insets. Buttons and text fields share the standard horizontal and
	/// vertical padding.
	package enum ControlPadding {
		package static let horizontal = LauncherVisuals.Control.standardHorizontalPadding
		package static let vertical = LauncherVisuals.Control.standardVerticalPadding
		package static let largeHorizontal = LauncherVisuals.Spacing.panel
		package static let segmentTrack = LauncherVisuals.Spacing.compact
		package static let segmentHorizontal: CGFloat = 10
		package static let segmentVertical = LauncherVisuals.Spacing.compact
	}

	package enum Typography {
		package static let pageTitle = Font.system(size: 22, weight: .medium)
		package static let sectionLabel = Font.system(size: 13, weight: .medium)
		package static let control = Font.system(size: 12, weight: .medium)
	}
}
