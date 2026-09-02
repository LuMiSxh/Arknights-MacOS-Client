// SPDX-License-Identifier: MPL-2.0

import Foundation

struct LiveContractReport: Codable, Sendable {
	static let schemaVersion = 1

	let schemaVersion: Int
	let checkedAt: String
	let trigger: String
	let runID: String
	let runURL: String
	let checks: [LiveContractCheck]

	init(checks: [LiveContractCheck], environment: [String: String]) {
		schemaVersion = Self.schemaVersion
		checkedAt = ISO8601DateFormatter().string(from: Date())
		trigger = environment["GITHUB_EVENT_NAME"] ?? "local"
		let runIdentifier = environment["GITHUB_RUN_ID"] ?? "local"
		runID = runIdentifier
		let repository = environment["GITHUB_REPOSITORY"] ?? "local/repository"
		runURL =
			environment["GITHUB_SERVER_URL"].map {
				"\($0)/\(repository)/actions/runs/\(runIdentifier)"
			} ?? "local"
		self.checks = checks
	}

	func writeIfRequested(environment: [String: String]) throws {
		guard let path = environment["ARKNIGHTS_CLIENT_CONTRACT_REPORT"] else { return }
		let data = try JSONEncoder.contractReport.encode(self)
		try data.write(to: URL(filePath: path), options: .atomic)
	}
}

struct LiveContractCheck: Codable, Sendable {
	enum Status: String, Codable, Sendable {
		case healthy
		case failed
		case blocked
	}

	let region: String
	let contract: String
	let status: Status
	let summary: String
}

extension JSONEncoder {
	fileprivate static var contractReport: JSONEncoder {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return encoder
	}
}
