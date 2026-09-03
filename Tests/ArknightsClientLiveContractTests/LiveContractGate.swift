// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LiveContractGate {
	static let environmentKey = "ARKNIGHTS_CLIENT_LIVE_CONTRACT_TESTS"
	static let optInToken = "RUN_YOSTAR_PUBLIC_NETWORK_SMOKE_TESTS"

	static var isEnabled: Bool {
		ProcessInfo.processInfo.environment[environmentKey] == optInToken
	}

	static let disabledComment =
		"Public-network test disabled; explicitly set \(environmentKey)=\(optInToken)."
}
