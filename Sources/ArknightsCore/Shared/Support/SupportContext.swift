// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The only operation context permitted in automatically prepared public reports.
package struct SupportContext: Equatable, Sendable {
	package let operation: SupportOperation
	package let region: SupportRegion?

	package init(operation: SupportOperation, region: SupportRegion?) {
		self.operation = operation
		self.region = region
	}
}
