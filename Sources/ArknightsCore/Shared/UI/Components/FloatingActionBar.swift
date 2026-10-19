// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared fade behind floating footer controls so scroll content remains legible.
package struct FloatingActionFooterFade: View {
	package let height: CGFloat?
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	package init(height: CGFloat? = nil) {
		self.height = height
	}

	package var body: some View {
		Group {
			if reduceTransparency {
				Color.black.opacity(0.72)
			} else {
				LinearGradient(
					colors: [.clear, Color.black.opacity(0.45)],
					startPoint: .top,
					endPoint: .bottom
				)
			}
		}
		.frame(height: height)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
		.allowsHitTesting(false)
	}
}

/// Shared floating glass container for modal and onboarding actions. Single-row actions remain
/// capsule-like; expanded action groups use a fixed-radius rounded rectangle.
package struct FloatingActionBar<Content: View>: View {
	let tint: Color
	var spacing: CGFloat = 12
	@ViewBuilder package let content: Content
	@State private var contentHeight: CGFloat = 0

	package init(tint: Color, spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
		self.tint = tint
		self.spacing = spacing
		self.content = content()
	}

	package var body: some View {
		HStack(spacing: spacing) {
			content
		}
		.padding(10)
		.background {
			GeometryReader { proxy in
				Color.clear.preference(
					key: FloatingActionBarHeightPreferenceKey.self,
					value: proxy.size.height
				)
			}
		}
		.adaptiveGlassEffect(tint: tint, in: barShape)
		.shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
		.onPreferenceChange(FloatingActionBarHeightPreferenceKey.self) { height in
			guard abs(height - contentHeight) > 0.5 else { return }
			contentHeight = height
		}
	}

	private var isExpanded: Bool {
		contentHeight > 56
	}

	private var barShape: RoundedRectangle {
		RoundedRectangle(
			cornerRadius: isExpanded ? LauncherVisuals.Radius.panel : 999,
			style: .continuous
		)
	}
}

private struct FloatingActionBarHeightPreferenceKey: PreferenceKey {
	static let defaultValue: CGFloat = 0

	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = max(value, nextValue())
	}
}

package struct FloatingDoneButton: View {
	var title = "Done"
	package let accentColor: Color
	let action: () -> Void

	package init(title: String = "Done", accentColor: Color, action: @escaping () -> Void) {
		self.title = title
		self.accentColor = accentColor
		self.action = action
	}

	package var body: some View {
		CapsuleActionButton(
			title: title,
			systemImage: "checkmark",
			tone: .accent(accentColor),
			action: action
		)
		.controlSize(.large)
		.keyboardShortcut(.defaultAction)
	}
}
