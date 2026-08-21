// SPDX-License-Identifier: MPL-2.0

import Foundation

struct IntelTranslationProcessResult: Equatable, Sendable {
	let status: Int32
	let output: String
}

enum IntelTranslationProcess {
	static func run(
		executable: URL,
		arguments: [String]
	) async throws -> IntelTranslationProcessResult {
		try await withCheckedThrowingContinuation { continuation in
			let process = Process()
			let output = Pipe()
			process.executableURL = executable
			process.arguments = arguments
			process.standardOutput = output
			process.standardError = output
			process.terminationHandler = { process in
				let data = output.fileHandleForReading.readDataToEndOfFile()
				continuation.resume(
					returning: IntelTranslationProcessResult(
						status: process.terminationStatus,
						output: String(decoding: data, as: UTF8.self)
					)
				)
			}
			do {
				try process.run()
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
}
