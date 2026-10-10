// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

enum LauncherUpdateOverlayPresentation {
	enum Motion: Equatable {
		case immediate
		case animated(initialDialogScale: CGFloat)
	}

	static func isPresented(
		destination: LauncherPresentationDestination?,
		driverIsPresented: Bool
	) -> Bool {
		destination == .update && driverIsPresented
	}

	static func motion(reduceMotion: Bool) -> Motion {
		guard !reduceMotion else { return .immediate }
		return .animated(initialDialogScale: 0.90)
	}
}

struct LauncherUpdateOverlay: View {
	let driver: LauncherUpdateUserDriver
	let accentColor: Color
	let hudTintColor: Color
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
		(reduceTransparency ? Color.black : Color.black.opacity(LauncherVisuals.overlayDim))
			.ignoresSafeArea()
			.opacity(isVisible ? 1 : 0)
			.animation(backgroundAnimation, value: isVisible)
			.accessibilityHidden(true)
	}

	private var updateDialog: some View {
		LauncherUpdateView(
			driver: driver,
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			checkForUpdates: checkForUpdates
		)
		.blur(radius: isVisible ? 0 : initialDialogBlur)
		.offset(y: isVisible ? 0 : initialDialogOffset)
		.scaleEffect(isVisible ? 1 : initialDialogScale)
		.opacity(isVisible ? 1 : 0)
		.animation(dialogAnimation, value: isVisible)
		.focusSection()
		.accessibilityAddTraits(.isModal)
	}

	private var motion: LauncherUpdateOverlayPresentation.Motion {
		LauncherUpdateOverlayPresentation.motion(reduceMotion: reduceMotion)
	}

	private var initialDialogScale: CGFloat {
		if case .animated(let scale) = motion { return scale }
		return 1
	}

	/// The dialog starts soft and slightly low, then springs into focus.
	private var initialDialogBlur: CGFloat {
		if case .animated = motion { return 10 }
		return 0
	}

	private var initialDialogOffset: CGFloat {
		if case .animated = motion { return 18 }
		return 0
	}

	private var backgroundAnimation: Animation? {
		LauncherMotion.animation(.backdrop, reduceMotion: reduceMotion)
	}

	private var dialogAnimation: Animation? {
		LauncherMotion.animation(.present, reduceMotion: reduceMotion)
	}
}
