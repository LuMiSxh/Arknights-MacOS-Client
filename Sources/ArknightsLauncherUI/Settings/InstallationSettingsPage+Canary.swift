// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

extension InstallationSettingsPage {
	@ViewBuilder var canaryStatusNote: some View {
		Text("There are no canary features right now.")
			.font(.caption)
			.foregroundStyle(theme.textSecondary)
	}
}
