// SPDX-License-Identifier: MPL-2.0

// A new child starts only when one finishes, so the group never exceeds the limit.
func withWindowedTaskGroup<Item: Sendable, Element: Sendable>(
	_ items: [Item],
	limit: Int,
	operation: @escaping @Sendable (Item) async throws -> Element,
	consume: (Element) -> Void = { _ in }
) async throws {
	precondition(limit > 0, "A windowed task group needs a limit of at least one")
	try await withThrowingTaskGroup(of: Element.self) { group in
		var nextIndex = 0
		func addNext() {
			guard nextIndex < items.count else { return }
			let item = items[nextIndex]
			nextIndex += 1
			group.addTask { try await operation(item) }
		}
		for _ in 0..<min(limit, items.count) { addNext() }
		do {
			while let element = try await group.next() {
				consume(element)
				addNext()
			}
		} catch {
			group.cancelAll()
			throw error
		}
	}
}
