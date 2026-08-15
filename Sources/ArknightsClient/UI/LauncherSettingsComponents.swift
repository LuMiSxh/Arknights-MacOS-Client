// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct SettingsPage<Content: View>: View {
	let title: String
	let subtitle: String
	@ViewBuilder let content: Content

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				VStack(alignment: .leading, spacing: 7) {
					Text(title)
						.font(.largeTitle.bold())
					Text(subtitle)
						.foregroundStyle(.secondary)
					HStack(spacing: 8) {
						Rectangle().fill(SettingsVisuals.cyan).frame(width: 72, height: 3)
						Rectangle().fill(.secondary.opacity(0.28))
							.frame(height: 1)
							.frame(maxWidth: .infinity)
					}
					.padding(.top, 5)
				}
				content
			}
			.padding(26)
		}
		.scrollIndicators(.hidden)
	}
}

struct SettingsPanel<Content: View>: View {
	let title: String
	let systemImage: String
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Label(title, systemImage: systemImage)
				.font(.headline)
				.symbolRenderingMode(.hierarchical)
			content
		}
		.padding(18)
		.frame(maxWidth: .infinity, alignment: .leading)
		.glassEffect(.regular, in: .rect(cornerRadius: 18))
	}
}

struct UpdateSettingsRow: View {
	let title: String
	let status: String
	@Binding var isEnabled: Bool
	let isChecking: Bool
	let check: () -> Void

	var body: some View {
		HStack(spacing: 16) {
			Toggle(title, isOn: $isEnabled)
				.frame(width: 180, alignment: .leading)
			Text(status)
				.foregroundStyle(.secondary)
				.lineLimit(1)
			Spacer()
			Button("Check Now", action: check)
				.disabled(isChecking)
		}
	}
}

struct SettingsActionRow<Actions: View>: View {
	let title: String
	let detail: String
	@ViewBuilder let actions: Actions

	var body: some View {
		HStack(spacing: 18) {
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			actions
		}
	}
}

struct DocumentLinkRow: View {
	let title: String
	let systemImage: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack {
				Label(title, systemImage: systemImage)
				Spacer()
				Image(systemName: "chevron.right")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.tertiary)
			}
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
	}
}
