// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A failure shown under the step or row that failed: what happened, what to do, and the support code.
package struct InlineFailureView: View {
	let message: String
	let code: SupportCode?
	@Environment(\.launcherTheme) private var theme

	package init(message: String, code: SupportCode?) {
		self.message = message
		self.code = code
	}

	package var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text(message)
				.font(.callout)
				.foregroundStyle(theme.textPrimary)
				.fixedSize(horizontal: false, vertical: true)
			if let code {
				HStack(spacing: LauncherTokens.Spacing.compact) {
					Text("Support code")
						.foregroundStyle(theme.textSecondary)
					Text(code.rawValue)
						.font(.callout.monospaced())
						.foregroundStyle(theme.dangerText)
						.textSelection(.enabled)
				}
				.font(.caption)
			}
		}
		.padding(.vertical, LauncherTokens.Spacing.compact)
	}
}
