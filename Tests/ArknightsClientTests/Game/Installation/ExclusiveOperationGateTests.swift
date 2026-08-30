// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func exclusiveOperationRejectsASecondStartUntilTheFirstFinishes() throws {
	var gate = ExclusiveOperationGate()
	let firstToken = gate.begin()
	let first = try #require(firstToken)

	#expect(gate.begin() == nil)

	gate.finish(first)

	#expect(gate.begin() != nil)
}

@Test
func staleOperationCannotFinishTheActiveOperation() throws {
	var gate = ExclusiveOperationGate()
	let activeToken = gate.begin()
	let active = try #require(activeToken)

	gate.finish(UUID())

	#expect(gate.owns(active))
}
