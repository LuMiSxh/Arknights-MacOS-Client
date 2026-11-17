// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Explains the two generated treatments without adding a second interaction to the gallery.
struct OperatorIconStylePreview: View {
	let catalog: PresetCatalogService
	let avatar: PresetAvatar?
	let accentHue: Double?
	@Environment(\.launcherTheme) private var theme
	private static let previewMinimumWidth: CGFloat = 284
	private static let previewMaximumWidth: CGFloat = 360

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.panel) {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
				Text("Generated Icon Styles")
					.font(.headline)
				Text("Your operator is applied to both icons.")
					.font(.caption)
					.foregroundStyle(theme.textSecondary)
			}

			if let avatar {
				CachedPresetOperatorPair(
					catalog: catalog,
					url: avatar.url,
					cacheKey: avatar.id,
					accentHue: accentHue
				)
				HStack(spacing: LauncherTokens.Spacing.panel) {
					styleLabel(
						"Launcher",
						detail: "Launcher style"
					)
					styleLabel(
						"Game",
						detail: "Original Arknights style"
					)
				}
			} else {
				ProgressView("Loading preview…")
					.frame(maxWidth: .infinity, minHeight: 82)
			}
		}
		.padding(LauncherTokens.Spacing.panel)
		.frame(minWidth: Self.previewMinimumWidth, maxWidth: Self.previewMaximumWidth)
	}

	private func styleLabel(
		_ title: String, detail: String
	)
		-> some View
	{
		VStack(spacing: LauncherTokens.Spacing.compact) {
			Text(title)
				.font(.caption.weight(.medium))
			Text(detail)
				.font(.caption)
				.foregroundStyle(theme.textSecondary)
				.multilineTextAlignment(.center)
				.lineLimit(2)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
	}
}
