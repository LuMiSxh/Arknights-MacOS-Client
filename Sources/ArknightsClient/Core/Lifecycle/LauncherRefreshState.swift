// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherRefreshState: Equatable, Sendable {
	case idle
	case checking(requestID: UUID?)

	var requestID: UUID? {
		guard case .checking(let requestID) = self else { return nil }
		return requestID
	}

	var isChecking: Bool {
		if case .checking = self { return true }
		return false
	}
}
