// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherFailureDetailView: View {
	let failure: LauncherFailurePresentation
	let accentColor: Color
	let hudTintColor: Color
	let perform: (RecoveryAction, UUID) -> Void
	private let troubleshootingMarkdown: String?
	@Environment(\.dismiss) private var dismiss

	init(
		failure: LauncherFailurePresentation,
		accentColor: Color,
		hudTintColor: Color,
		perform: @escaping (RecoveryAction, UUID) -> Void
	) {
		self.failure = failure
		self.accentColor = accentColor
		self.hudTintColor = hudTintColor
		self.perform = perform
		troubleshootingMarkdown = failure.code?.bundledTroubleshootingMarkdown()
	}

	var body: some View {
		ThemedModalView(
			title: L10n.string(HomeStrings.needsAttention),
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			width: failure.code == nil ? 620 : 820,
			height: failure.code == nil ? 430 : 600,
			minimumHeight: 430
		) {
			VStack(alignment: .leading, spacing: 20) {
				if let code = failure.code {
					LauncherSupportCodeLabel(code: code, accentColor: accentColor)
				}

				Text(failure.message)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if let troubleshootingMarkdown {
					Divider()
					MarkdownDocument(
						source: troubleshootingMarkdown,
						accentColor: accentColor
					)
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
		HStack(spacing: 8) {
			if hasSupportActions {
				supportActions
				Divider()
					.frame(height: 24)
					.padding(.horizontal, 2)
			}
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
		.controlSize(.large)
	}

	private var supportActions: some View {
		HStack(spacing: 8) {
			if failure.actions.contains(.openTroubleshooting) {
				supportAction(
					.openTroubleshooting,
					title: L10n.string(HomeStrings.openTroubleshooting),
					systemImage: "arrow.up.right.square"
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
		failure.actions.contains(.openTroubleshooting)
			|| failure.actions.contains(.reportProblem)
	}
}
