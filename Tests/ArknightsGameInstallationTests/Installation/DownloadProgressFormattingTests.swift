// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsGameInstallation

struct DownloadProgressFormattingTests {
	@Test("unsigned byte counts clamp to the supported signed range")
	func unsignedByteCountClamps() {
		#expect(
			DownloadProgressFormatting.byteCount(UInt64.max)
				== DownloadProgressFormatting.byteCount(Int64.max)
		)
	}
}
