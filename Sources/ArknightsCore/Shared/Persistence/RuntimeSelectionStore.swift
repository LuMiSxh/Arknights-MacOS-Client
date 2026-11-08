// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import Foundation

/// Reads and writes the small selection document that names the chosen runtime lane.
package struct RuntimeSelectionStore: Sendable {
	package let fileURL: URL

	private let files = JSONFileStore(
		maximumBytes: AppConstants.Runtime.runtimeSelectionMaximumBytes
	)

	package init(fileURL: URL) {
		self.fileURL = fileURL
	}

	/// Returns the persisted selection, or the OS default when no file exists.
	package func load(access: RuntimeAccess = RuntimeAccess()) throws -> RuntimeSelection {
		try files.read(RuntimeSelection.self, at: fileURL)
			?? RuntimeSelection(selected: access.defaultLane)
	}

	package func save(_ selection: RuntimeSelection) throws {
		try files.write(selection, to: fileURL, createParentDirectory: true)
	}
}
