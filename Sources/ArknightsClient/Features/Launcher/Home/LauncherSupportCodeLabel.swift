// SPDX-License-Identifier: MPL-2.0

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

					HomeStrings.errorCodeAccessibility(
						code: code.rawValue,
						spelling: code.rawValue.map(String.init).joined(separator: " ")
					)
				)
			)
	}
}
