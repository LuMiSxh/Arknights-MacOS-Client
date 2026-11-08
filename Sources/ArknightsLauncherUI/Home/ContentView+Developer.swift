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
		var developerExpandedPill: ExpandedPill? {
			guard let pill = model.developerSimulation?.expandedPill else { return nil }
			switch pill {
			case .music: return .music
			case .version: return .version
			case .status: return .status
			case .none: return nil
			}
		}
		package var developerAccessibilityMusicTitle: String? {
			guard model.isDeveloperMode else { return nil }
			return model.developerAccessibilityMusicTitle
		}
	#else
		var developerSimulationBinding: DeveloperSimulationBinding? { nil }
		var developerExpandedPill: ExpandedPill? { nil }
		package var developerAccessibilityMusicTitle: String? { nil }
	#endif
}
