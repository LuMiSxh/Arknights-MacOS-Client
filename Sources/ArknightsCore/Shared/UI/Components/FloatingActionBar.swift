// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared fade behind floating footer controls so scroll content remains legible.
package struct FloatingActionFooterFade: View {
	package let height: CGFloat?
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.launcherTheme) private var theme

	/// Light mode fades into the light sheet; a black fade greys the bottom edge.
	private var isDark: Bool { colorScheme == .dark }

	package init(height: CGFloat? = nil) {
		self.height = height
	}

	package var body: some View {
		Group {
			if reduceTransparency {
				// Opaque in this mode, so the footer matches the sheet instead of a black strip.
				theme.sheetTint
			} else {
				LinearGradient(
					colors: [.clear, isDark ? Color.black.opacity(0.45) : theme.sheetTint],
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

	var spacing: CGFloat = 12
	@ViewBuilder package let content: Content
	@State private var contentHeight: CGFloat = 0

	package init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
		self.spacing = spacing
		self.content = content()
	}

	package var body: some View {
		HStack(spacing: spacing) {
			content
		}
		.padding(8)
		.background {
			GeometryReader { proxy in
				Color.clear.preference(
					key: FloatingActionBarHeightPreferenceKey.self,
					value: proxy.size.height
				)
			}
		}
		.launcherSurface(.footer, in: barShape)
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
	let action: () -> Void
	package init(title: String = "Done", action: @escaping () -> Void) {
		self.title = title
		self.action = action
	}

	package var body: some View {
		CapsuleActionButton(
			title: title,
			systemImage: "checkmark",
			tone: .accent,
			action: action
		)
		.controlSize(.large)
		.keyboardShortcut(.defaultAction)
	}
}
