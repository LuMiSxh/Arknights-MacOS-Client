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
			title: HomeStrings.needsAttention,
			hudTintColor: hudTintColor,
			width: failure.code == nil ? 620 : 820,
			height: failure.code == nil ? 430 : 600,
			minimumHeight: 430
		) {
			VStack(alignment: .leading, spacing: 20) {
				if let code = failure.code {
					LauncherSupportCodeLabel(code: code)
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
		ViewThatFits(in: .horizontal) {
			HStack(spacing: 8) {
				recoveryActions
				if hasSupportActions {
					supportActions
					Divider()
						.frame(height: 24)
						.padding(.horizontal, 2)
				}
				dismissButton
			}
			VStack(alignment: .trailing, spacing: LauncherVisuals.Spacing.control) {
				HStack(spacing: 8) {
					recoveryActions
				}
				HStack(spacing: 8) {
					if hasSupportActions {
						supportActions
					}
					dismissButton
				}
			}
		}
		.controlSize(.large)
	}

	@ViewBuilder
	private var recoveryActions: some View {
		if failure.actions.contains(.installRosetta) {
			recoveryButton(
				action: .installRosetta,
				title: LauncherStrings.rosettaInstall,
				systemImage: "arrow.down.circle",
				tone: .accent(accentColor)
			)
		}
		if failure.actions.contains(.retry) {
			recoveryButton(
				action: .retry,
				title: HomeStrings.retry,
				systemImage: "arrow.clockwise",
				tone: .accent(accentColor)
			)
		}
		if failure.actions.contains(.repair) {
			recoveryButton(
				action: .repair,
				title: HomeStrings.repair,
				systemImage: "wrench.and.screwdriver",
				tone: failure.actions.contains(.retry) ? .neutral : .accent(accentColor)
			)
		}
	}

	@ViewBuilder
	private func recoveryButton(
		action recoveryAction: RecoveryAction,
		title: String,
		systemImage: String,
		tone: CapsuleActionTone
	) -> some View {
		let button = CapsuleActionButton(
			title: title,
			systemImage: systemImage,
			tone: tone
		) {
			perform(recoveryAction, failure.id)
		}
		if recoveryAction == defaultRecoveryAction {
			button.keyboardShortcut(.defaultAction)
		} else {
			button
		}
	}

	private var dismissButton: some View {
		CapsuleActionButton(
			title: LauncherStrings.popupDone,
			tone: .neutral,
			action: { dismiss() }
		)
		.keyboardShortcut(.cancelAction)
	}

	private var supportActions: some View {
		HStack(spacing: 8) {
			if failure.actions.contains(.openTroubleshooting) {
				supportAction(
					.openTroubleshooting,
					title: HomeStrings.openTroubleshooting,
					systemImage: "arrow.up.right.square"
				)
			}
			if failure.actions.contains(.reportProblem) {
				supportAction(
					.reportProblem,
					title: HomeStrings.reportProblem,
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

	private var defaultRecoveryAction: RecoveryAction? {
		if failure.actions.contains(.installRosetta) { return .installRosetta }
		if failure.actions.contains(.retry) { return .retry }
		if failure.actions.contains(.repair) { return .repair }
		return nil
	}
}
