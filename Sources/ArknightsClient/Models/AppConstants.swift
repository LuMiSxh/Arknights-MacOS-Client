// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AppConstants {
	enum Network {
		static let concurrentDownloads = 6
		static let maxDownloadAttempts = 3
		static let retryBackoffStep: Duration = .milliseconds(400)
	}

	enum IO {
		static let checksumBufferSize = 4 * 1024 * 1024
	}

	enum Timeouts {
		static let processTerminateGracePeriod: TimeInterval = 3
		static let processKillGracePeriod: TimeInterval = 1
		static let windowReadiness: Duration = .seconds(90)
		static let windowPollInterval: Duration = .milliseconds(250)
	}
}
