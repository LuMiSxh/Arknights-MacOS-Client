// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The user's runtime lane choice. It is the only persisted runtime choice: there is no active
/// version, previous version, or installed-version list. A lane is installed when its pinned
/// version directory exists.
package struct RuntimeSelection: Codable, Equatable, Sendable {
	package var selected: RuntimeLane

	package init(selected: RuntimeLane = .x86) {
		self.selected = selected
	}
}
