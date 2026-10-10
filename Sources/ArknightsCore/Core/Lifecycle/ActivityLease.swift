// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Proof that one operation owns the launcher's exclusive activity.
/// `LauncherLifecycleStore` rejects any change that carries a lease it did not issue last.
package struct ActivityLease: Hashable, Sendable {
	let token: UUID

	package init(token: UUID = UUID()) {
		self.token = token
	}
}
