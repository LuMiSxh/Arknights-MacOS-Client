// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared floating glass container for modal and onboarding actions.
struct FloatingActionBar<Content: View>: View {
	let tint: Color
	var spacing: CGFloat = 12
	@ViewBuilder let content: Content

	var body: some View {
		HStack(spacing: spacing) {
			content
		}
		.padding(10)
		.adaptiveGlassEffect(tint: tint, in: Capsule())
		.shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
	}
}

/// Standard confirmation action used by floating modal footers.
struct FloatingDoneButton: View {
	let accentColor: Color
	let action: () -> Void

	var body: some View {
		CapsuleActionButton(
			title: "Done", systemImage: "checkmark", tone: .accent(accentColor), action: action
		)
		.controlSize(.large)
		.keyboardShortcut(.defaultAction)
	}
}
