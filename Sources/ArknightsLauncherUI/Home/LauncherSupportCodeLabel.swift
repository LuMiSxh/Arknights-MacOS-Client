// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct LauncherSupportCodeLabel: View {
	let code: SupportCode
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		Text(code.rawValue)
			.font(.title3.monospaced().weight(.semibold))
			.foregroundStyle(theme.dangerText)
			.textSelection(.enabled)
			.accessibilityLabel(
				Text(

					"Error code \(code.rawValue), spelled \(code.rawValue.map(String.init).joined(separator: " "))"
				)
			)
	}
}
