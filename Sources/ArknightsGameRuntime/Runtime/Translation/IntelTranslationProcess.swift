// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

package struct IntelTranslationProcessResult: Equatable, Sendable {
	let status: Int32
	let output: String

	package init(status: Int32, output: String) {
		self.status = status
		self.output = output
	}
}

enum IntelTranslationProcess {
	private static let cancellationWrapper = """
		child=
		cancelled=0
		terminate_child() {
			cancelled=1
			if [ -z "$child" ]; then return; fi
			trap - TERM INT
			kill -KILL "$child" 2>/dev/null
			wait "$child" 2>/dev/null
			exit 143
		}
		trap terminate_child TERM INT
		"$@" &
		child=$!
		if [ "$cancelled" -eq 1 ]; then terminate_child; fi
		wait "$child"
		status=$?
		trap - TERM INT
		exit "$status"
		"""

	static func run(
		executable: URL,
		arguments: [String]
	) async throws -> IntelTranslationProcessResult {
		let result = try await ChildProcess(
			executable: URL(filePath: "/bin/sh"),
			arguments: ["-c", cancellationWrapper, "intel-translation-helper", executable.path]
				+ arguments,
			output: .captured(maximumBytes: AppConstants.IO.processDiagnosticMaximumBytes)
		).run()
		return IntelTranslationProcessResult(
			status: result.status,
			output: String(decoding: result.output, as: UTF8.self)
		)
	}
}
