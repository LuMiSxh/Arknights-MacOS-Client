// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Loads one bounded avatar asset and renders it for one isolated icon destination.
struct CachedPresetOperatorIcon: View {
	let url: URL
	let cacheKey: String
	let treatment: OperatorIconTreatment
	let accentHue: Double?

	@State private var image: NSImage?
	@State private var hasFailed = false

	var body: some View {
		Group {
			if let image {
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else if hasFailed {
				Label("Icon preview unavailable", systemImage: "person.crop.square.fill")
					.labelStyle(.iconOnly)
					.font(.title2)
					.foregroundStyle(.tertiary)
			} else {
				ProgressView()
					.controlSize(.small)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			treatment == .launcher ? "Launcher icon preview" : "Game icon preview"
		)
		.task(id: renderIdentifier) {
			image = nil
			hasFailed = false
			do {
				let data = try await PresetCatalogService.shared.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard
					!Task.isCancelled,
					let rendered = AppIconRenderer.createPresetIcon(
						from: data,
						treatment: treatment,
						accentHue: effectiveAccentHue
					)
				else { return }
				image = rendered
			} catch {
				hasFailed = true
			}
		}
	}

	private var renderIdentifier: String {
		"\(url.absoluteString)|\(treatment.rawValue)|\(effectiveAccentHue ?? -1)"
	}

	private var effectiveAccentHue: Double? {
		treatment == .launcher ? accentHue : nil
	}
}
