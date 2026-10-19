// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Frame rules that differ between the HUD pills. Unset values leave that dimension unconstrained.
package struct HUDPillSizing {
	package var collapsedHeight: CGFloat
	package var collapsedMaxWidth: CGFloat?
	package var expandedWidth: CGFloat?
	package var expandedMinWidth: CGFloat?
	package var expandedMaxWidth: CGFloat?
	package var expandedMinHeight: CGFloat?
	/// Keeps the width at its ideal size while expanded; a collapsed pill always hugs its content.
	package var fixesWidthWhenExpanded = false

	package init(
		collapsedHeight: CGFloat,
		collapsedMaxWidth: CGFloat? = nil,
		expandedWidth: CGFloat? = nil,
		expandedMinWidth: CGFloat? = nil,
		expandedMaxWidth: CGFloat? = nil,
		expandedMinHeight: CGFloat? = nil,
		fixesWidthWhenExpanded: Bool = false
	) {
		self.collapsedHeight = collapsedHeight
		self.collapsedMaxWidth = collapsedMaxWidth
		self.expandedWidth = expandedWidth
		self.expandedMinWidth = expandedMinWidth
		self.expandedMaxWidth = expandedMaxWidth
		self.expandedMinHeight = expandedMinHeight
		self.fixesWidthWhenExpanded = fixesWidthWhenExpanded
	}
}

/// A HUD pill that collapses to a capsule and expands to a rounded rectangle. The header toggles
/// the detail content; with `canExpand` false it renders as a plain label without a disclosure.
package struct ExpandableHUDPill<Title: View, Detail: View>: View {
	let systemImage: String
	let iconFont: Font
	let toggleNoun: String
	let accessibilityValue: String
	let accentColor: Color
	let hudTintColor: Color
	let canExpand: Bool
	let expandedSpacing: CGFloat
	let sizing: HUDPillSizing
	@Binding var isExpanded: Bool
	let title: Title
	let detail: Detail
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	/// - Parameter toggleNoun: Completes the "Show …" and "Hide …" accessibility label and help.
	package init(
		systemImage: String,
		iconFont: Font = .caption.weight(.semibold),
		toggleNoun: String,
		accessibilityValue: String,
		accentColor: Color,
		hudTintColor: Color,
		canExpand: Bool = true,
		expandedSpacing: CGFloat = 10,
		sizing: HUDPillSizing,
		isExpanded: Binding<Bool>,
		@ViewBuilder title: () -> Title,
		@ViewBuilder detail: () -> Detail
	) {
		self.systemImage = systemImage
		self.iconFont = iconFont
		self.toggleNoun = toggleNoun
		self.accessibilityValue = accessibilityValue
		self.accentColor = accentColor
		self.hudTintColor = hudTintColor
		self.canExpand = canExpand
		self.expandedSpacing = expandedSpacing
		self.sizing = sizing
		_isExpanded = isExpanded
		self.title = title()
		self.detail = detail()
	}

	private var expanded: Bool { isExpanded && canExpand }

	package var body: some View {
		VStack(alignment: .leading, spacing: expanded ? expandedSpacing : 0) {
			header
			if expanded {
				detail.transition(
					HUDPillMotion.expandedContentTransition(reduceMotion: reduceMotion))
			}
		}
		.padding(.vertical, expanded ? 11 : 0)
		.frame(width: expanded ? sizing.expandedWidth : nil)
		.frame(
			minHeight: expanded ? sizing.expandedMinHeight : sizing.collapsedHeight,
			alignment: expanded ? .topLeading : .center
		)
		.frame(
			minWidth: expanded ? sizing.expandedMinWidth : nil,
			maxWidth: expanded ? sizing.expandedMaxWidth : sizing.collapsedMaxWidth
		)
		.fixedSize(horizontal: sizing.fixesWidthWhenExpanded || !expanded, vertical: false)
		.hudPillSurface(isExpanded: expanded, tint: hudTintColor)
		.shadow(
			color: Color.black.opacity(expanded ? 0.35 : 0),
			radius: expanded ? 12 : 0,
			y: expanded ? 5 : 0
		)
		.accessibilityElement(children: .contain)
		.onExitCommand(perform: collapse)
	}

	@ViewBuilder
	private var header: some View {
		if canExpand {
			let label = expanded ? "Hide \(toggleNoun)" : "Show \(toggleNoun)"
			Button(action: toggle) { headerLabel }
				.buttonStyle(ActionPressStyle())
				.keyboardFocusIndicator(in: Capsule())
				.accessibilityLabel(label)
				.accessibilityValue(Text(accessibilityValue))
				.help(label)
		} else {
			headerLabel
		}
	}

	private var headerLabel: some View {
		HStack(spacing: 5) {
			Image(systemName: systemImage)
				.font(iconFont)
				.adaptiveControlForeground(accentColor)
				.accessibilityHidden(true)
			title
			Spacer(minLength: canExpand ? 6 : 0)
			if canExpand {
				Image(systemName: expanded ? "chevron.up" : "chevron.down")
					.font(.caption.bold())
					.adaptiveControlForeground(accentColor)
					.contentTransition(HUDPillMotion.chevronTransition(reduceMotion: reduceMotion))
					.accessibilityHidden(true)
			}
		}
		.padding(.horizontal, expanded ? 14 : 12)
		.frame(minHeight: expanded ? nil : sizing.collapsedHeight)
		.contentShape(Rectangle())
	}

	private func toggle() {
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			isExpanded.toggle()
		}
	}

	private func collapse() {
		guard isExpanded else { return }
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			isExpanded = false
		}
	}
}
