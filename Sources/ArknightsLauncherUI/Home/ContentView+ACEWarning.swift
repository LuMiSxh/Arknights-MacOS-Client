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
			LauncherStrings.aceWarningTitle,
			isPresented: Binding(
				get: { model.pendingACEWarningRegion != nil },
				set: { isPresented in
					if !isPresented { model.actions.cancelACEWarning() }
				}
			),
			titleVisibility: .visible
		) {
			Button(LauncherStrings.aceWarningAction, role: .destructive) {
				model.actions.confirmACEWarningAndLaunch()
			}
			Button(LauncherStrings.cancel, role: .cancel) {
				model.actions.cancelACEWarning()
			}
		} message: {
			Text(LauncherStrings.aceWarningDetail)
		}
	}
}
