// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct RosettaInstallationConfirmationModifier: ViewModifier {
	@Binding var isPresented: Bool
	let install: () -> Void

	func body(content: Content) -> some View {
		content.confirmationDialog(
			"Install Rosetta 2?",
			isPresented: $isPresented,
			titleVisibility: .visible
		) {
			Button("Install Rosetta 2", action: install)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(
				"Rosetta 2 is Apple system software that lets this Apple silicon Mac run the bundled Intel-based Wine runtime. Continuing runs Apple’s software update tool and accepts Apple’s Rosetta license."
			)
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
