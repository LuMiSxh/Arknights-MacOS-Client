// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

@Test
private func aSavedScreenshotIsRenamedIntoPlaceAndNeverReplacesAnExistingFile() throws {
	let temporary = try TemporaryDirectory("ScreenshotFileWriterTests")
	defer { temporary.remove() }
	let image = makeTestImage()

	let first = try ScreenshotFileWriter.write(image, to: temporary.url, baseName: "Shot")
	let original = try Data(contentsOf: first)
	let second = try ScreenshotFileWriter.write(image, to: temporary.url, baseName: "Shot")
	let third = try ScreenshotFileWriter.write(image, to: temporary.url, baseName: "Shot")

	#expect(
		[first, second, third].map(\.lastPathComponent) == [
			"Shot.png", "Shot (2).png", "Shot (3).png",
		])
	#expect(try Data(contentsOf: first) == original)
	// No `.part` file survives a successful save.
	let names = try FileManager.default.contentsOfDirectory(atPath: temporary.url.path)
	#expect(names.allSatisfy { !$0.hasSuffix(".part") })
	#expect(names.count == 3)
}
