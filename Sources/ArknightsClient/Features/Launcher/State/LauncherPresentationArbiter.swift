// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherPresentationDestination: Equatable, Identifiable {
	case settings
	case update
	case failure(LauncherFailurePresentation)
	case popup

	var id: String {
		switch self {
		case .settings: "settings"
		case .update: "update"
		case .failure(let failure): "failure-\(failure.id.uuidString)"
		case .popup: "popup"
		}
	}

	var priority: Int {
		switch self {
		case .popup: 0
		case .settings: 1
		case .update: 2
		case .failure: 3
		}
	}
	var isSheet: Bool { self != .update }
}

enum LauncherConfirmation: Equatable, Identifiable {
	case rosetta
	case repair(UUID)

	var id: String {
		switch self {
		case .rosetta: "rosetta"
		case .repair(let id): "repair-\(id.uuidString)"
		}
	}
}

struct LauncherPresentationArbiter {
	private(set) var current: LauncherPresentationDestination?
	private(set) var queued: LauncherPresentationDestination?

	mutating func request(_ destination: LauncherPresentationDestination) {
		if let current {
			guard destination.priority > current.priority else { return }
			queued = destination
			self.current = nil
			return
		}
		if let queued {
			if destination.priority > queued.priority { self.queued = destination }
			return
		}
		current = destination
	}

	mutating func dismissCurrent() {
		current = nil
	}

	mutating func didDismiss() {
		guard current == nil else { return }
		current = queued
		queued = nil
	}

	mutating func removeFailures() {
		if case .failure = current { current = nil }
		if case .failure = queued { queued = nil }
	}
}
