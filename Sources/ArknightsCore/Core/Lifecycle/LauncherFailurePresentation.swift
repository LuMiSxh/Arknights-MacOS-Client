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
