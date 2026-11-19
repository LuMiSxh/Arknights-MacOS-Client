// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A snapshot of one failed operation. It carries no controller state or executable closures.
package struct LauncherFailurePresentation: Equatable, Sendable, Identifiable {
	package let id: UUID
	/// A dialog title that replaces the default. Used by startup notices with their own wording.
	package let title: String?
	package let message: String
	package let code: SupportCode?
	package let context: SupportContext
	package let actions: [RecoveryAction]
	package let blocksGameLaunch: Bool
	/// False when the notice offers only explicit actions and no ordinary dismissal.
	package let showsDismissAction: Bool
	/// True while the notice's action runs. The view shows progress and disables the actions.
	package let isBusy: Bool

	/// Whether the failure belongs to the game download that setup starts.
	package var isGameDownloadFailure: Bool {
		context.operation == .install || context.operation == .update
	}

	/// Whether first-run setup shows this failure inline on its Install step. While setup is
	/// visible, the Home failure sheet waits for these.
	package var isShownInSetup: Bool {
		isGameDownloadFailure || context.operation == .intelTranslationPreflight
			|| context.operation == .rosettaInstallation || context.operation == .runtimeSetup
	}

	package init(
		id: UUID,
		title: String? = nil,
		message: String,
		code: SupportCode?,
		context: SupportContext,
		actions: [RecoveryAction],
		blocksGameLaunch: Bool = false,
		showsDismissAction: Bool = true,
		isBusy: Bool = false
	) {
		self.id = id
		self.title = title
		self.message = message
		self.code = code
		self.context = context
		self.actions = actions
		self.blocksGameLaunch = blocksGameLaunch
		self.showsDismissAction = showsDismissAction
		self.isBusy = isBusy
	}
}
