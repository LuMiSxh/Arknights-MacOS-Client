// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct RosettaInstallationConfirmationModifier: ViewModifier {
	@Binding var isPresented: Bool
	let install: () -> Void

	func body(content: Content) -> some View {
		content.confirmationDialog(
			L10n.string(LauncherStrings.rosettaConfirmationTitle),
			isPresented: $isPresented,
			titleVisibility: .visible
		) {
			Button(L10n.string(LauncherStrings.rosettaInstall), action: install)
			Button(L10n.string(LauncherStrings.rosettaCancel), role: .cancel) {}
		} message: {
			Text(L10n.string(LauncherStrings.rosettaConfirmationMessage))
		}
	}
}

extension View {
	func confirmsRosettaInstallation(
		isPresented: Binding<Bool>,
		install: @escaping () -> Void
	) -> some View {
		modifier(
			RosettaInstallationConfirmationModifier(
				isPresented: isPresented,
				install: install
			)
		)
	}
}
