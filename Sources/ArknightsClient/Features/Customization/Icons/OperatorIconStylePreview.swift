// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Explains the two generated treatments without adding a second interaction to the gallery.
struct OperatorIconStylePreview: View {
	let catalog: PresetCatalogService
	let avatar: PresetAvatar?
	let accentHue: Double?
	let accentColor: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			VStack(alignment: .leading, spacing: 3) {
				Text("Generated Icon Styles")
					.font(.headline)
				Text("Your operator is applied to both icons.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			if let avatar {
				CachedPresetOperatorPair(
					catalog: catalog,
					url: avatar.url,
					cacheKey: avatar.id,
					accentHue: accentHue
				)
				HStack(spacing: 16) {
					styleLabel("Launcher", detail: "Launcher style")
					styleLabel("Game", detail: "Original Arknights style")
				}
			} else {
				ProgressView("Loading preview…")
					.frame(maxWidth: .infinity, minHeight: 82)
			}
		}
		.padding(18)
		.frame(width: 282)
		.background(accentColor.opacity(0.06))
		.preferredColorScheme(.dark)
	}

	private func styleLabel(_ title: String, detail: String) -> some View {
		VStack(spacing: 2) {
			Text(title)
				.font(.caption.bold())
			Text(detail)
				.font(.caption)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.lineLimit(2)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(width: 104)
	}
}
