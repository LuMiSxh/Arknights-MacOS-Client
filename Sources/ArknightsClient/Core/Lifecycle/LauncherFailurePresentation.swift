// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A snapshot of one failed operation. It carries no controller state or executable closures.
struct LauncherFailurePresentation: Equatable, Sendable, Identifiable {
	let id: UUID
	let message: String
	let code: SupportCode?
	let context: SupportContext
	let actions: [RecoveryAction]
	let blocksGameLaunch: Bool

	init(
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
