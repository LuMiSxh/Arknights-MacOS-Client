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
			.map(Self.recoveryMarkdown)
	}

	/// The footer owns Report a Problem and Save Diagnostics now, so keep only the recovery
	/// section from the bundled article.
	private static func recoveryMarkdown(_ markdown: String) -> String {
		guard let range = markdown.range(of: "\n## Report the problem") else {
			return markdown
		}
		return String(markdown[..<range.lowerBound])
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
			subtitle: failure.message,
			width: failure.code == nil ? 620 : 720,
			height: failure.code == nil ? 432 : 600,
			minimumHeight: 432
		) {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.section) {
				if let code = failure.code {
					SettingsPanel(title: "Support code") {
						HStack(alignment: .center, spacing: LauncherTokens.Spacing.content) {
							LauncherSupportCodeLabel(code: code)
							Spacer(minLength: 0)
							CapsuleActionButton(
								title: didCopySupportCode ? "Copied" : "Copy",
								systemImage: didCopySupportCode ? "checkmark" : "doc.on.doc",
								tone: .neutral,
								presentation: .compact
							) {
								copySupportCode(code)
							}
						}
						.task(id: didCopySupportCode) {
							guard didCopySupportCode else { return }
							do {
								try await Task.sleep(
									for: AppConstants.Support.copyConfirmationDuration)
							} catch {
								return
							}
							didCopySupportCode = false
						}
					}
				}

				if let troubleshootingMarkdown {
					SettingsHairline()
					MarkdownDocument(source: troubleshootingMarkdown, style: .compact)
						.frame(maxWidth: 640, alignment: .leading)
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
					helpMenu
				}
				dismissButton
			}
			VStack(alignment: .trailing, spacing: LauncherTokens.Spacing.control) {
				HStack(spacing: LauncherTokens.Spacing.control) {
					recoveryActions
				}
				HStack(spacing: LauncherTokens.Spacing.control) {
					if hasSupportActions {
						helpMenu
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

	private var helpMenu: some View {
		GlassActionMenu(title: "Get Help") {
			if failure.actions.contains(.openTroubleshooting) {
				Button {
					perform(.openTroubleshooting, failure)
				} label: {
					Label("Open on Website", systemImage: "arrow.up.right.square")
				}
			}
			if failure.actions.contains(.reportProblem) {
				Button {
					perform(.reportProblem, failure)
				} label: {
					Label("Report a Problem", systemImage: "ladybug")
				}
				Button {
					saveDiagnostics()
				} label: {
					Label("Save Diagnostics", systemImage: "square.and.arrow.down")
				}
				.disabled(isSavingDiagnostics)
			}
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
