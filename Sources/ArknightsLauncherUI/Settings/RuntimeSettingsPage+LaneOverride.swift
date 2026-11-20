// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

/// What the user can pick in the Danger zone: the launcher's own choice, or one allowed lane.
enum RuntimeLaneChoice: Hashable {
	case automatic
	case lane(RuntimeLane)

	var override: RuntimeLane? {
		if case .lane(let lane) = self { lane } else { nil }
	}
}

extension RuntimeSettingsPage {
	/// The override picker. Lanes this macOS does not allow are not offered.
	var runtimeChoiceRow: some View {
		SettingsActionRow(
			title: "Runtime choice",
			detail:
				"The launcher picks the runtime for this Mac. Override it only to work around a problem."
		) {
			GlassMenuPicker(
				selection: runtimeChoiceBinding,
				options: runtimeChoices,
				isDisabled: runtimeChangesDisabled
			)
		}
	}

	private var runtimeChoices: [(value: RuntimeLaneChoice, title: String)] {
		[(.automatic, "Automatic")]
			+ RuntimeLane.allCases
			.filter { runtimeSelection.availableLanes.contains($0) }
			.map { (.lane($0), $0.title) }
	}

	private var runtimeChoiceBinding: Binding<RuntimeLaneChoice> {
		Binding(
			get: { runtimeSelection.laneOverride.map { .lane($0) } ?? .automatic },
			set: { choice in
				if effectiveLane(of: choice) != runtimeSelection.selectedLane,
					runtimeSelection.switchRequiresWarning
				{
					pendingRuntimeChoice = choice
				} else {
					applyRuntimeChoice(choice)
				}
			}
		)
	}

	private func effectiveLane(of choice: RuntimeLaneChoice) -> RuntimeLane {
		choice.override ?? runtimeSelection.access.defaultLane
	}

	/// An installed lane switches at once. A missing lane downloads first, which makes it the
	/// override. Clearing the override may leave the launcher's lane missing: it downloads too.
	private func applyRuntimeChoice(_ choice: RuntimeLaneChoice) {
		let override = choice.override
		let lane = effectiveLane(of: choice)
		let isInstalled = runtimeSelection.state(for: lane) == .current
		Task {
			if let override, !isInstalled {
				_ = await actions.installRuntime(override)
				return
			}
			guard actions.selectRuntimeOverride(override) else { return }
			if !isInstalled { _ = await actions.installRuntime(lane) }
		}
	}

	// MARK: - Switch confirmation

	private var pendingRuntimeLane: RuntimeLane? {
		pendingRuntimeChoice.map(effectiveLane(of:))
	}

	var runtimeSwitchDialogTitle: String {
		guard let lane = pendingRuntimeLane else { return RuntimeSwitchWarning.title }
		return lane == .arm ? "Switch to ARM64?" : "Switch to x86_64?"
	}

	var runtimeSwitchButtonTitle: String {
		guard let lane = pendingRuntimeLane else { return "Switch" }
		return runtimeSelection.state(for: lane) == .current
			? "Switch" : "Switch and Download"
	}

	var runtimeSwitchMessage: String {
		guard let lane = pendingRuntimeLane, let pin = runtimeSelection.pinnedRuntime(for: lane)
		else { return RuntimeSwitchWarning.message }
		return RuntimeSwitchWarning.message(
			for: pin,
			isInstalled: runtimeSelection.state(for: lane) == .current
		)
	}

	func confirmRuntimeSwitch() {
		guard let choice = pendingRuntimeChoice else { return }
		pendingRuntimeChoice = nil
		applyRuntimeChoice(choice)
	}
}
