// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherFailureDetailView: View {
	let failure: LauncherFailurePresentation
	let accentColor: Color
	let hudTintColor: Color
	let perform: (RecoveryAction, UUID) -> Void
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		ThemedModalView(
			title: L10n.string(HomeStrings.needsAttention),
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			width: 620,
			height: 430
		) {
			VStack(alignment: .leading, spacing: 20) {
				if let code = failure.code {
					LauncherSupportCodeLabel(code: code, accentColor: accentColor)
				}

				Text(failure.message)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if hasSupportActions {
					Divider()
					supportActions
				}
			}
			.textSelection(.enabled)
		} actions: {
			footerActions
		}
		.onExitCommand(perform: dismiss.callAsFunction)
	}

	@ViewBuilder
	private var footerActions: some View {
		if failure.actions.contains(.retry) {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.retry),
				systemImage: "arrow.clockwise",
				tone: .neutral
			) {
				perform(.retry, failure.id)
			}
		}
		if failure.actions.contains(.repair) {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.repair),
				systemImage: "wrench.and.screwdriver",
				tone: .neutral
			) {
				perform(.repair, failure.id)
			}
		}
		FloatingDoneButton(accentColor: accentColor) {
			dismiss()
		}
	}

	private var supportActions: some View {
		HStack(spacing: 10) {
			if failure.actions.contains(.showLogs) {
				supportAction(
					.showLogs,
					title: L10n.string(HomeStrings.showLogs),
					systemImage: "doc.text.magnifyingglass"
				)
			}
			if failure.actions.contains(.openTroubleshooting) {
				supportAction(
					.openTroubleshooting,
					title: L10n.string(HomeStrings.openTroubleshooting),
					systemImage: "book.pages"
				)
			}
			if failure.actions.contains(.reportProblem) {
				supportAction(
					.reportProblem,
					title: L10n.string(HomeStrings.reportProblem),
					systemImage: "ladybug"
				)
			}
		}
	}

	private func supportAction(
		_ action: RecoveryAction,
		title: String,
		systemImage: String
	) -> some View {
		CapsuleActionButton(
			title: title,
			systemImage: systemImage,
			tone: .neutral
		) {
			perform(action, failure.id)
		}
	}

	private var hasSupportActions: Bool {
		failure.actions.contains(.showLogs)
			|| failure.actions.contains(.openTroubleshooting)
			|| failure.actions.contains(.reportProblem)
	}
}
