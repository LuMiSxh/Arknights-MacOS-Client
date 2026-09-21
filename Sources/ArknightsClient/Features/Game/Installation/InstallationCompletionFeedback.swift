// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Ephemeral feedback for one installation operation that reached a verified state.
struct InstallationCompletionFeedback: Equatable, Sendable, Identifiable {
	let id: UUID
	let region: GameRegion
}
