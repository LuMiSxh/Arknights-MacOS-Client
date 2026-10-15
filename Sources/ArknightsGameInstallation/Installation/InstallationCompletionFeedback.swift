// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Ephemeral feedback for one installation operation that reached a verified state.
package struct InstallationCompletionFeedback: Equatable, Sendable, Identifiable {
	package let id: UUID
	package let region: GameRegion
}
