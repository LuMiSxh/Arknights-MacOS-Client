// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A snapshot of one failed operation. It carries no controller state or executable closures.
package struct LauncherFailurePresentation: Equatable, Sendable, Identifiable {
	package let id: UUID
	package let message: String
	package let code: SupportCode?
	package let context: SupportContext
	package let actions: [RecoveryAction]
	package let blocksGameLaunch: Bool

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
		message: String,
		code: SupportCode?,
		context: SupportContext,
		actions: [RecoveryAction],
		blocksGameLaunch: Bool = false
	) {
		self.id = id
		self.message = message
		self.code = code
		self.context = context
		self.actions = actions
		self.blocksGameLaunch = blocksGameLaunch
	}
}
