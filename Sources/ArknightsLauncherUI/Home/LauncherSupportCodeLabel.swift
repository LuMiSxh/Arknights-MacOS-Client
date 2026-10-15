// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct LauncherSupportCodeLabel: View {
	let code: SupportCode

	var body: some View {
		Text(code.rawValue)
			.font(.caption.monospaced().bold())
			.foregroundStyle(LauncherVisuals.dangerForeground)
			.textSelection(.enabled)
			.accessibilityLabel(
				Text(

					"Error code \(code.rawValue), spelled \(code.rawValue.map(String.init).joined(separator: " "))"
				)
			)
	}
}
