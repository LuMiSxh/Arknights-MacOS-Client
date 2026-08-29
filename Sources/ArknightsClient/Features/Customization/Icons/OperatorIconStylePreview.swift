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
				Text(L10n.string(CustomizationStrings.iconPreviewTitle))
					.font(.headline)
				Text(L10n.string(CustomizationStrings.iconPreviewSubtitle))
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
					styleLabel(
						CustomizationStrings.launcherStyleTitle,
						detail: CustomizationStrings.launcherStyleDetail
					)
					styleLabel(
						CustomizationStrings.gameStyleTitle,
						detail: CustomizationStrings.gameStyleDetail
					)
				}
			} else {
				ProgressView(L10n.string(CustomizationStrings.iconPreviewLoading))
					.frame(maxWidth: .infinity, minHeight: 82)
			}
		}
		.padding(18)
		.frame(minWidth: 282, maxWidth: 360)
		.background(accentColor.opacity(0.06))
		.preferredColorScheme(.dark)
	}

	private func styleLabel(_ title: LocalizedStringResource, detail: LocalizedStringResource)
		-> some View
	{
		VStack(spacing: 2) {
			Text(L10n.string(title))
				.font(.caption.bold())
			Text(L10n.string(detail))
				.font(.caption)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.lineLimit(2)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity)
	}
}
