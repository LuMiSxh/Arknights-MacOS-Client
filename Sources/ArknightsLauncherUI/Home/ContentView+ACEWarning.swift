// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension View {
	func aceWarningConfirmation(model: LauncherViewModel) -> some View {
		modifier(ACEWarningConfirmationModifier(model: model))
	}
}

private struct ACEWarningConfirmationModifier: ViewModifier {
	let model: LauncherViewModel

	func body(content: Content) -> some View {
		content.confirmationDialog(
			"ACE Anti-Cheat client",
			isPresented: Binding(
				get: { model.pendingACEWarningRegion != nil },
				set: { isPresented in
					if !isPresented { model.actions.cancelACEWarning() }
				}
			),
			titleVisibility: .visible
		) {
			Button("Play at my own risk", role: .destructive) {
				model.actions.confirmACEWarningAndLaunch()
			}
			Button("Cancel", role: .cancel) {
				model.actions.cancelACEWarning()
			}
		} message: {
			Text(
				"This client uses ACE Anti-Cheat. Running it through Wine is unofficial and may cause compatibility issues or consequences for your account or the service. If you continue, you play at your own risk."
			)
		}
	}
}
