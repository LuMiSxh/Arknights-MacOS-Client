// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

struct GameInstallerSchedulingTests {
	private func file(_ path: String, size: Int64, hash: String = "h") -> ManifestFile {
		ManifestFile(path: path, hash: hash, size: String(size))
	}

	@Test
	func partialFilesComeFirstThenLargestFirst() {
		let a = file("a", size: 100)
		let b = file("b", size: 50)
		let c = file("c", size: 200)
		let d = file("d", size: 10)
		let partials = ["b": Int64(10), "d": Int64(5)]
		let order = GameInstaller.downloadOrder([a, b, c, d]) { partials[$0.path] ?? 0 }
		#expect(order == [b, d, c, a])
	}

	@Test
	func largerFilesDownloadFirstWithoutPartials() {
		let files = [file("s", size: 10), file("l", size: 30), file("m", size: 20)]
		let order = GameInstaller.downloadOrder(files) { _ in 0 }
		#expect(order.map(\.path) == ["l", "m", "s"])
	}

	@Test
	func equalSizesBreakTiesByPath() {
		let files = [file("c", size: 5), file("a", size: 5), file("b", size: 5)]
		let order = GameInstaller.downloadOrder(files) { _ in 0 }
		#expect(order.map(\.path) == ["a", "b", "c"])
	}

	@Test
	func emptyListReturnsEmpty() {
		let order = GameInstaller.downloadOrder([]) { _ in
			Issue.record("partialBytes must not be called for an empty list")
			return 0
		}
		#expect(order.isEmpty)
	}

	@Test
	func identicalEntriesKeepInputOrderAndRepeatCallsMatch() {
		let first = file("x", size: 7, hash: "one")
		let second = file("x", size: 7, hash: "two")
		let files = [second, first]
		let order = GameInstaller.downloadOrder(files) { _ in 0 }
		#expect(order == [second, first])
		#expect(GameInstaller.downloadOrder(files) { _ in 0 } == order)
	}
}
