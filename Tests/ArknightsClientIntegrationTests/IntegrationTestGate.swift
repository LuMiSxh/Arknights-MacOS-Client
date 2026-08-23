// SPDX-License-Identifier: MPL-2.0

import Foundation

enum IntegrationTestGate {
	static let environmentKey = "ARKNIGHTS_CLIENT_INTEGRATION_TESTS"
	static let optInToken = "RUN_DETERMINISTIC_INTEGRATION_TESTS"

	static var isEnabled: Bool {
		ProcessInfo.processInfo.environment[environmentKey] == optInToken
	}

	static let disabledComment =
		"Integration tests are disabled; run them through the repository test command."
}
