// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A button that opens a browser, Finder, Mail, or System Settings. It has no ellipsis and carries the external-link icon.
package struct ExternalLinkButton: View {
	let title: String
	var presentation: CapsuleActionPresentation = .compact
	let action: () -> Void

	package init(
		title: String,
		presentation: CapsuleActionPresentation = .compact,
		action: @escaping () -> Void
	) {
		self.title = title
		self.presentation = presentation
		self.action = action
	}

	package var body: some View {
		CapsuleActionButton(
			title: title,
			systemImage: "arrow.up.right.square",
			tone: .neutral,
			presentation: presentation,
			action: action
		)
	}
}
