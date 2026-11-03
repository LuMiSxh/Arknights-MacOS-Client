// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsGameRuntime

private let gamePID: Int32 = 100

private struct LocatorCase: CustomTestStringConvertible, Sendable {
	let name: String
	let candidates: [GameWindowCandidate]
	let expected: UInt32?
	var testDescription: String { name }
}

private let locatorCases: [LocatorCase] = [
	LocatorCase(
		name: "picks the game window",
		candidates: [
			GameWindowCandidate(
				windowID: 1, ownerProcessIdentifier: gamePID, width: 1600, height: 900)
		],
		expected: 1),
	LocatorCase(
		name: "picks the largest of several game-sized windows",
		candidates: [
			GameWindowCandidate(
				windowID: 1, ownerProcessIdentifier: gamePID, width: 1280, height: 720),
			GameWindowCandidate(
				windowID: 2, ownerProcessIdentifier: gamePID, width: 1920, height: 1080),
		],
		expected: 2),
	LocatorCase(
		name: "ignores a small helper window",
		candidates: [
			GameWindowCandidate(
				windowID: 1, ownerProcessIdentifier: gamePID, width: 300, height: 200)
		],
		expected: nil),
	LocatorCase(
		name: "ignores another process",
		candidates: [
			GameWindowCandidate(windowID: 1, ownerProcessIdentifier: 7, width: 1920, height: 1080)
		],
		expected: nil),
	LocatorCase(
		name: "ignores a window above layer zero",
		candidates: [
			GameWindowCandidate(
				windowID: 1, ownerProcessIdentifier: gamePID, layer: 25, width: 1920, height: 1080)
		],
		expected: nil),
	LocatorCase(
		name: "ignores an off-screen or transparent window",
		candidates: [
			GameWindowCandidate(
				windowID: 1, ownerProcessIdentifier: gamePID, isOnScreen: false, width: 1920,
				height: 1080),
			GameWindowCandidate(
				windowID: 2, ownerProcessIdentifier: gamePID, alpha: 0, width: 1920, height: 1080),
		],
		expected: nil),
]

@Test(arguments: locatorCases)
private func locatorSelectsOnlyTheGameWindow(_ testCase: LocatorCase) {
	let selected = GameWindowLocator.select(testCase.candidates, pid: gamePID)
	#expect(selected?.windowID == testCase.expected)
}

@Test
private func fallbackAcceptsASmallWindowOfTheSameProcessButNeverAnotherProcess() {
	let candidates = [
		GameWindowCandidate(windowID: 1, ownerProcessIdentifier: gamePID, width: 300, height: 200),
		GameWindowCandidate(windowID: 2, ownerProcessIdentifier: 7, width: 1920, height: 1080),
	]
	#expect(GameWindowLocator.selectFallback(candidates, pid: gamePID)?.windowID == 1)
	#expect(GameWindowLocator.selectFallback(candidates, pid: 8) == nil)
}
