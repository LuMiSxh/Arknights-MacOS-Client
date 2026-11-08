// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

enum LauncherUpdateOverlayPresentation {
	static func isPresented(
		destination: LauncherPresentationDestination?,
		driverIsPresented: Bool
	) -> Bool {
		destination == .update && driverIsPresented
	}
}

struct LauncherUpdateOverlay: View {
	@Environment(\.launcherTheme) private var theme
	let driver: LauncherUpdateUserDriver

	let reduceTransparency: Bool
	let checkForUpdates: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Namespace private var focusNamespace
	@State private var isVisible = false

	var body: some View {
		ZStack {
			backgroundDim
			updateDialog
		}
		.focusScope(focusNamespace)
		.onAppear {
			isVisible = true
		}
	}

	private var backgroundDim: some View {
		(reduceTransparency ? LauncherVisuals.opaqueDim : theme.modalDim)
			.ignoresSafeArea()
			.opacity(isVisible ? 1 : 0)
			.animation(backgroundAnimation, value: isVisible)
			.accessibilityHidden(true)
	}

	private var updateDialog: some View {
		LauncherUpdateView(
			driver: driver,

			checkForUpdates: checkForUpdates
		)
		.scaleEffect(isVisible ? 1 : initialDialogScale)
		.opacity(isVisible ? 1 : 0)
		.animation(dialogAnimation, value: isVisible)
		.focusSection()
		.accessibilityAddTraits(.isModal)
	}

	private var initialDialogScale: CGFloat {
		reduceMotion ? 1 : LauncherMotion.overlayEntranceScale
	}

	private var backgroundAnimation: Animation? {
		LauncherMotion.animation(.backdrop, reduceMotion: reduceMotion)
	}

	private var dialogAnimation: Animation? {
		LauncherMotion.animation(.present, reduceMotion: reduceMotion)
	}
}
