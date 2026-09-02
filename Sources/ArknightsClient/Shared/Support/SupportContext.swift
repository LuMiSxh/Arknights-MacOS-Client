// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The only operation context permitted in automatically prepared public reports.
struct SupportContext: Equatable, Sendable {
	let operation: SupportOperation
	let region: SupportRegion?
}
