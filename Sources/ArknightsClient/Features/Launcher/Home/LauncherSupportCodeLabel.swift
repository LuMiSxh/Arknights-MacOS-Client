// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherSupportCodeLabel: View {
	let code: SupportCode
	let accentColor: Color

	var body: some View {
		Text(code.rawValue)
			.font(.caption.monospaced().bold())
			.foregroundStyle(accentColor)
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
