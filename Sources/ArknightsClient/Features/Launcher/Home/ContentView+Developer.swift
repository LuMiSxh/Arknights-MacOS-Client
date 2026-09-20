// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension ContentView {
	#if DEBUG
		var developerSimulationBinding: DeveloperSimulationBinding? {
			guard model.isDeveloperMode else { return nil }
			return Binding(
				get: { model.developerSimulation ?? DeveloperSimulationState() },
				set: { model.applyDeveloperSimulation($0) })
		}
		var developerExpandedPillID: String? {
			model.developerSimulation?.expandedPill.rawValue
		}
		var developerAccessibilityMusicTitle: String? {
			guard model.isDeveloperMode else { return nil }
			return model.developerAccessibilityMusicTitle
		}
		var developerPopup: ((String, String) -> Void)? {
			guard model.isDeveloperMode else { return nil }
			return { title, message in
				model.applyDeveloperCustomPopup(title: title, markdown: message)
			}
		}
	#else
		var developerSimulationBinding: DeveloperSimulationBinding? { nil }
		var developerExpandedPillID: String? { nil }
		var developerAccessibilityMusicTitle: String? { nil }
		var developerPopup: ((String, String) -> Void)? { nil }
	#endif
}
