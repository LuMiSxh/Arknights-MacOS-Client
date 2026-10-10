// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct RosettaInstallationConfirmationModifier: ViewModifier {
	@Binding var isPresented: Bool
	let install: () -> Void

	func body(content: Content) -> some View {
		content.confirmationDialog(
			RuntimeStrings.rosettaConfirmationTitle,
			isPresented: $isPresented,
			titleVisibility: .visible
		) {
			Button(RuntimeStrings.rosettaInstall, action: install)
			Button(RuntimeStrings.rosettaCancel, role: .cancel) {}
		} message: {
			Text(RuntimeStrings.rosettaConfirmationMessage)
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
