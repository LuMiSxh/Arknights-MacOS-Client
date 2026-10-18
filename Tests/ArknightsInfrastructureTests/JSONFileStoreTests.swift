// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct JSONFileStoreTests {
	private struct Document: Codable, Equatable {
		var b: Int
		var a: Date
	}

	/// Documents are written with sorted keys and ISO 8601 dates, and read back unchanged.
	@Test
	func writesSortedPrettyJSONWithISODatesAndReadsItBack() throws {
		let directory = try TemporaryDirectory("JSONFileStoreTests")
		defer { directory.remove() }
		let url = directory.url.appending(path: "document.json")
		let document = Document(b: 2, a: Date(timeIntervalSince1970: 0))

		let pretty = JSONFileStore(maximumBytes: 1_024, iso8601Dates: true)
		try pretty.write(document, to: url, createParentDirectory: true)
		#expect(
			try Data(contentsOf: url)
				== Data("{\n  \"a\" : \"1970-01-01T00:00:00Z\",\n  \"b\" : 2\n}\n".utf8))
		#expect(try pretty.read(Document.self, at: url) == document)

		let compact = JSONFileStore(maximumBytes: 1_024, prettyPrinted: false)
		#expect(try compact.encode(["b": 2, "a": 1]) == Data("{\"a\":1,\"b\":2}\n".utf8))
	}

	/// The size limit applies to writes and reads. A missing document is not an error.
	@Test
	func rejectsOversizedDocumentsInBothDirections() throws {
		let directory = try TemporaryDirectory("JSONFileStoreTests")
		defer { directory.remove() }
		let url = directory.url.appending(path: "document.json")
		let store = JSONFileStore(maximumBytes: 16)

		#expect(throws: JSONFileStoreError.self) {
			try store.write(["key": String(repeating: "x", count: 32)], to: url)
		}
		#expect(!FileManager.default.fileExists(atPath: url.path))

		try Data(repeating: 0x20, count: 17).write(to: url)
		#expect(throws: BoundedFileReadError.self) {
			try store.read([String: String].self, at: url)
		}
		#expect(
			try store.read([String: String].self, at: directory.url.appending(path: "missing"))
				== nil)
	}
}
