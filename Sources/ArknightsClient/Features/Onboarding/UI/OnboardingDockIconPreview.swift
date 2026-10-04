// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

/// Shows the launcher and game Dock icons as they are right now, so choosing an operator has a
/// visible result inside setup.
struct OnboardingDockIconPreview: View {
	let customization: CustomizationController
	@State private var gameIcon: NSImage?

	var body: some View {
		HStack(spacing: LauncherVisuals.Spacing.panel) {
			iconTile(
				Image(nsImage: customization.launcherIconManager.currentIcon),
				title: OnboardingStrings.dockLauncherIcon)
			iconTile(gameIconImage, title: OnboardingStrings.dockGameIcon)
			Spacer(minLength: 0)
		}
		// The game icon only exists as a file once an operator or custom image is chosen.
		.task(id: customization.launcherIconManager.currentIcon) { await loadGameIcon() }
		.task(id: customization.hasCustomGameIcon) { await loadGameIcon() }
	}

	private var gameIconImage: Image {
		gameIcon.map { Image(nsImage: $0) } ?? Image(systemName: "gamecontroller.fill")
	}

	private func iconTile(_ image: Image, title: String) -> some View {
		VStack(spacing: LauncherVisuals.Spacing.tight) {
			image
				.resizable()
				.scaledToFit()
				.frame(width: 64, height: 64)
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.accessibilityElement(children: .combine)
	}

	private func loadGameIcon() async {
		guard customization.hasCustomGameIcon else {
			gameIcon = nil
			return
		}
		let url = customization.paths.customGameIcon
		// An unreadable file keeps the placeholder, which is what players see without a custom icon.
		let data = await Task.detached { try? Data(contentsOf: url) }.value
		gameIcon = data.flatMap(NSImage.init(data:))
	}
}
