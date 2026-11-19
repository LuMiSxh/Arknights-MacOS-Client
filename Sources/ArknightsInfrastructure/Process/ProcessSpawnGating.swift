// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Runs a spawn only while new children are allowed.
///
/// Implementations wrap the process's existing `terminationHandler`, so install handlers before
/// calling `runIfAllowed`.
package protocol ProcessSpawnGating: Sendable {
	func runIfAllowed<T>(process: Process, _ operation: () throws -> T) throws -> T
}
