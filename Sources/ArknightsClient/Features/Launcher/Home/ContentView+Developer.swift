// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension ContentView {
	#if DEBUG
		var developerScenarioBinding: DeveloperScenarioBinding? {
			guard model.isDeveloperMode else { return nil }
			return Binding(
				get: { model.developerScenario ?? .ready },
				set: { model.applyDeveloperScenario($0) })
		}
		var developerPopup: ((String, String) -> Void)? {
			guard model.isDeveloperMode else { return nil }
			return { title, message in
				model.applyDeveloperCustomPopup(title: title, markdown: message)
			}
		}
	#else
		var developerScenarioBinding: DeveloperScenarioBinding? { nil }
		var developerPopup: ((String, String) -> Void)? { nil }
	#endif
}
