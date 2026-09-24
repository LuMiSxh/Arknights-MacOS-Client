// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum LauncherUpdateOverlayPresentation {
	enum Motion: Equatable {
		case immediate
		case animated(
			backgroundDuration: TimeInterval,
			dialogDuration: TimeInterval,
			initialDialogScale: CGFloat)
	}

	static func isPresented(
		destination: LauncherPresentationDestination?,
		driverIsPresented: Bool
	) -> Bool {
		destination == .update && driverIsPresented
	}

	static func motion(reduceMotion: Bool) -> Motion {
		guard !reduceMotion else { return .immediate }
		return .animated(
			backgroundDuration: 0.18,
			dialogDuration: 0.22,
			initialDialogScale: 0.985)
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
		(reduceTransparency ? Color.black : Color.black.opacity(0.55))
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
		.opacity(isVisible ? 1 : 0)
		.scaleEffect(isVisible ? 1 : initialDialogScale)
		.animation(dialogAnimation, value: isVisible)
		.focusSection()
		.accessibilityAddTraits(.isModal)
	}

	private var motion: LauncherUpdateOverlayPresentation.Motion {
		LauncherUpdateOverlayPresentation.motion(reduceMotion: reduceMotion)
	}

	private var initialDialogScale: CGFloat {
		if case .animated(_, _, let scale) = motion { return scale }
		return 1
	}

	private var backgroundAnimation: Animation? {
		if case .animated(let duration, _, _) = motion {
			return .easeOut(duration: duration)
		}
		return nil
	}

	private var dialogAnimation: Animation? {
		if case .animated(_, let duration, _) = motion {
			return .easeOut(duration: duration)
		}
		return nil
	}
}
