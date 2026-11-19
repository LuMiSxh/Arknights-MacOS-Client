// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// The Home status line for a transfer: title with percentage, byte detail, and transfer rate.
/// Callers supply plain values, so only the caller that owns progress reads it per tick.
struct DownloadStatusLine: View {
	let title: String
	let widestTitle: String
	let detail: String?
	let rate: String?
	let accessibilityValue: String
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
			ViewThatFits(in: .horizontal) {
				HStack(
					alignment: .firstTextBaseline, spacing: LauncherTokens.Spacing.content
				) {
					percentageLabel
					progressDetail
					transferDetail
				}
				VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
					percentageLabel
					HStack(
						alignment: .firstTextBaseline, spacing: LauncherTokens.Spacing.control
					) {
						progressDetail
						transferDetail
					}
				}
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(title))
		.accessibilityValue(Text(accessibilityValue))
	}

	private var percentageLabel: some View {
		ZStack(alignment: .leading) {
			Text(widestTitle)
				.font(LauncherTokens.Typography.statusPercent)
				.monospacedDigit()
				.hidden()
				.accessibilityHidden(true)
			Text(title)
				.font(LauncherTokens.Typography.statusPercent)
				.monospacedDigit()
				.contentTransition(reduceMotion ? .identity : .numericText())
				.animation(
					LauncherMotion.animation(.state, reduceMotion: reduceMotion),
					value: title
				)
				.fixedSize(horizontal: true, vertical: false)
		}
		.fixedSize(horizontal: true, vertical: false)
	}

	private var progressDetail: some View {
		Text(detail ?? "")
			.font(.caption)
			.foregroundStyle(.secondary)
			.monospacedDigit()
			.frame(
				minWidth: AppConstants.HUD.downloadProgressDetailMinWidth,
				alignment: .leading
			)
			.fixedSize(horizontal: false, vertical: true)
			.layoutPriority(1)
			.accessibilityLabel(Text(detail ?? ""))
	}

	@ViewBuilder
	private var transferDetail: some View {
		if let rate {
			Text(rate)
				.monospacedDigit()
				.frame(
					minWidth: AppConstants.HUD.downloadSpeedDetailMinWidth,
					alignment: .leading
				)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.accessibilityElement(children: .combine)
		}
	}
}
