// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import SwiftUI

struct LauncherFailureDetailView: View {
	@Environment(\.launcherTheme) private var theme
	let failure: LauncherFailurePresentation

	let perform: (RecoveryAction, LauncherFailurePresentation) -> Void
	let isSavingDiagnostics: Bool
	let saveDiagnostics: () -> Void
	let onDismiss: () -> Void
	private let troubleshootingMarkdown: String?
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var didCopySupportCode = false

	init(
		failure: LauncherFailurePresentation,
		perform: @escaping (RecoveryAction, LauncherFailurePresentation) -> Void,
		isSavingDiagnostics: Bool,
		saveDiagnostics: @escaping () -> Void,
		onDismiss: @escaping () -> Void
	) {
		self.failure = failure
		self.perform = perform
		self.isSavingDiagnostics = isSavingDiagnostics
		self.saveDiagnostics = saveDiagnostics
		self.onDismiss = onDismiss
		troubleshootingMarkdown = failure.code?.bundledTroubleshootingMarkdown()
	}

	private func copySupportCode(_ code: SupportCode) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(code.rawValue, forType: .string)
		withAnimation(LauncherMotion.animation(.state, reduceMotion: reduceMotion)) {
			didCopySupportCode = true
		}
	}

	var body: some View {
		ThemedModalView(
			title: "Needs attention",

			width: failure.code == nil ? 620 : 820,
			height: failure.code == nil ? 432 : 600,
			minimumHeight: 432
		) {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.section) {
				if let code = failure.code {
					HStack(alignment: .center, spacing: LauncherTokens.Spacing.content) {
						LauncherSupportCodeLabel(code: code)
						IconActionButton(
							title: "Copy Support Code",
							systemImage: didCopySupportCode ? "checkmark" : "doc.on.doc",
							surface: .neutral
						) {
							copySupportCode(code)
						}
					}
					.task(id: didCopySupportCode) {
						guard didCopySupportCode else { return }
						do {
							try await Task.sleep(for: AppConstants.Support.copyConfirmationDuration)
						} catch {
							return
						}
						didCopySupportCode = false
					}
				}

				Text(failure.message)
					.foregroundStyle(theme.textSecondary)
					.fixedSize(horizontal: false, vertical: true)

				if let troubleshootingMarkdown {
					Divider()
					MarkdownDocument(
						source: troubleshootingMarkdown
					)
				}
			}
			.textSelection(.enabled)
		} actions: {
			footerActions
		}
		.onExitCommand(perform: dismissFailure)
	}

	private func dismissFailure() {
		// The environment dismissal targets the live sheet. The explicit closure still clears
		// presentation state when SwiftUI already replaced that sheet.
		dismiss()
		onDismiss()
	}

	@ViewBuilder
	private var footerActions: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: LauncherTokens.Spacing.control) {
				recoveryActions
				if hasSupportActions {
					supportActions
					Divider()
						.frame(height: 24)
						.padding(.horizontal, LauncherTokens.Spacing.compact)
				}
				dismissButton
			}
			VStack(alignment: .trailing, spacing: LauncherTokens.Spacing.control) {
				HStack(spacing: LauncherTokens.Spacing.control) {
					recoveryActions
				}
				HStack(spacing: LauncherTokens.Spacing.control) {
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
				title: "Install Rosetta 2",
				systemImage: "arrow.down.circle",
				tone: .accent
			)
		}
		if failure.actions.contains(.retry) {
			recoveryButton(
				action: .retry,
				title: "Retry",
				systemImage: "arrow.clockwise",
				tone: .accent
			)
		}
		if failure.actions.contains(.repair) {
			recoveryButton(
				action: .repair,
				title: "Repair",
				systemImage: "wrench.and.screwdriver",
				tone: failure.actions.contains(.retry) ? .neutral : .accent
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
			perform(recoveryAction, failure)
		}
		if recoveryAction == defaultRecoveryAction {
			button.keyboardShortcut(.defaultAction)
		} else {
			button
		}
	}

	private var dismissButton: some View {
		CapsuleActionButton(
			title: "Done",
			tone: .neutral,
			action: dismissFailure
		)
		.keyboardShortcut(.cancelAction)
	}

	// Three buttons do not fit the narrow modal on one line, so the footer stacks instead.
	private var supportActions: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: LauncherTokens.Spacing.control) { supportButtons }
			VStack(alignment: .trailing, spacing: LauncherTokens.Spacing.control) { supportButtons }
		}
	}

	@ViewBuilder
	private var supportButtons: some View {
		if failure.actions.contains(.openTroubleshooting) {
			supportAction(
				.openTroubleshooting,
				title: "Open on Website",
				systemImage: "arrow.up.right.square"
			)
		}
		if failure.actions.contains(.reportProblem) {
			supportAction(
				.reportProblem,
				title: "Report a Problem",
				systemImage: "ladybug"
			)
			supportButton(
				title: "Save Diagnostics",
				systemImage: "square.and.arrow.down"
			) {
				saveDiagnostics()
			}
			.disabled(isSavingDiagnostics)
		}
	}

	private func supportAction(
		_ action: RecoveryAction,
		title: String,
		systemImage: String
	) -> some View {
		supportButton(title: title, systemImage: systemImage) {
			perform(action, failure)
		}
	}

	private func supportButton(
		title: String,
		systemImage: String,
		action: @escaping () -> Void
	) -> some View {
		CapsuleActionButton(
			title: title,
			systemImage: systemImage,
			tone: .neutral,
			action: action
		)
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
