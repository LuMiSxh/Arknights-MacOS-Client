// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct OnboardingWelcomeView: View {
	let updateState: OnboardingUpdateState
	let requiredSchema: Int?
	let retry: () -> Void

	var body: some View {
		OnboardingPage(
			step: .welcome,
			subtitle: requiredSchema == nil
				? "Welcome to Arknights Client. Setup checks for a launcher update, then sets your server, install, display, and launcher options"
				: "This version needs you to go through setup once more. Your current settings are the starting point"
		) {
			if let requiredSchema {
				SettingsPanel(
					title: "Why setup is required",
					tone: .warning
				) {
					Text(Self.requiredSetupReason(schema: requiredSchema))
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			SettingsPanel(title: "Launcher update") {
				OnboardingStatusRow(
					title: statusTitle,
					detail: updateDetail,
					systemImage: statusImage,
					tone: updatePanelTone
				) {
					updateAction
				}
			}
		}
	}

	private var statusTitle: String {
		switch updateState {
		case .checking: "Checking for launcher updates"
		case .current: "Ready for setup"
		case .updateRequired: "Update before setup"
		case .checkFailed: "Update check unavailable"
		}
	}

	static func requiredSetupReason(schema: Int) -> String {
		switch schema {
		case 2:
			"Display settings work differently in this version. Confirm display mode, rendering and cursor once."
		case 3:
			"This version adds light mode and Home controls, reorganizes settings, and changes fullscreen. Go through each step once to review your setup."
		case 4:
			"Setup changed in version 1.0. Your server, runtime, location, and preferences stay as they are. Nothing downloads unless you change something."
		default:
			"The launcher changed how an important setting works. Go through each step once so everything keeps working."
		}
	}

	private var updatePanelTone: SettingsPanelTone {
		switch updateState {
		case .current: .success
		case .updateRequired, .checkFailed: .warning
		case .checking: .neutral
		}
	}

	private var updateDetail: String? {
		switch updateState {
		case .checking: nil
		case .current: "This launcher is up to date. Setup can continue."
		case .updateRequired(let version):
			"Version \(version) is available. Install the newer launcher and open it again. Setup waits so its instructions match the version you use."
		case .checkFailed:
			"The launcher could not look for updates. You can continue now; it will try again later."
		}
	}

	@ViewBuilder
	private var updateAction: some View {
		switch updateState {
		case .checkFailed:
			CapsuleActionButton(
				title: "Try Again",
				systemImage: "arrow.clockwise",
				tone: .accent,
				action: retry
			)
		case .checking, .current, .updateRequired:
			EmptyView()
		}
	}

	private var statusImage: String? {
		switch updateState {
		case .checking: nil
		case .current: "checkmark.shield"
		case .updateRequired: "arrow.down.app"
		case .checkFailed: "wifi.exclamationmark"
		}
	}
}
