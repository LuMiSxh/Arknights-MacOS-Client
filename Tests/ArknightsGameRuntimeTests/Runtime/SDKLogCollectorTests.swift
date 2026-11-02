// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

@Test(arguments: [(GamePublisher.hypergryph, true), (.gryphline, true), (.yostar, false)])
func sdkLogsAreCopiedForNonYostarPublishersOnly(publisher: GamePublisher, copies: Bool) throws {
	let temporary = try TemporaryDirectory("SDKLogCollectorTests")
	defer { temporary.remove() }
	let source = temporary.url.appending(path: "sdklogs", directoryHint: .isDirectory)
	let destination = temporary.url.appending(path: "out", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
	try Data("sdk".utf8).write(to: source.appending(path: "u8sdk_pc.log"))
	try Data("abcdefghij".utf8).write(to: source.appending(path: "HGWebview.log"))
	try Data("skip".utf8).write(to: source.appending(path: "HGEventLog.log"))

	try SDKLogCollector.collect(
		publisher: publisher, source: source, destination: destination, maximumBytes: 4)

	let copied = (try? FileManager.default.contentsOfDirectory(atPath: destination.path)) ?? []
	#expect(Set(copied) == (copies ? ["u8sdk_pc.log", "HGWebview.log"] : []))
	if copies {
		#expect(
			try Data(contentsOf: destination.appending(path: "u8sdk_pc.log")) == Data("sdk".utf8))
		// The cap keeps the last bytes.
		#expect(
			try Data(contentsOf: destination.appending(path: "HGWebview.log")) == Data("ghij".utf8))
	}
}
