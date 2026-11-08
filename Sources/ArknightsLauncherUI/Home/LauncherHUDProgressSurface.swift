// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

// The surface and `content` read only state that changes on transitions. The outline overlay
// is the only view that reads the per-tick `installation.progress`, so progress updates
// do not invalidate `content`. While an outline is possible, the overlay draws the border.
struct HUDProgressSurface<Content: View>: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let runtimeSelection: RuntimeSelectionController
	@ViewBuilder let content: () -> Content

	var body: some View {
		let supportsOutline =
			runtimeSelection.isInstalling
			|| LauncherDownloadProgressPresentation.supportsOutline(
				status: lifecycle.state.presentation.status,
				hasPartialDownload: installation.hasPartialDownload,
				hasFailure: lifecycle.state.presentation.failure != nil
			)
		content()
			.hudPillSurface(showsBorder: !supportsOutline)
			.overlay {
				if supportsOutline {
					HUDProgressOutline(
						lifecycle: lifecycle,
						installation: installation,
						runtimeSelection: runtimeSelection
					)
				}
			}
	}
}

private struct HUDProgressOutline: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let runtimeSelection: RuntimeSelectionController

	var body: some View {
		if runtimeSelection.isInstalling {
			HUDRuntimeOutline(runtimeSelection: runtimeSelection)
		} else {
			HUDDownloadOutline(lifecycle: lifecycle, installation: installation)
		}
	}
}

// Only this leaf reads the per-tick runtime progress.
private struct HUDRuntimeOutline: View {
	let runtimeSelection: RuntimeSelectionController

	var body: some View {
		HUDPillProgressOutline(
			progress: RuntimeInstallPresentation.outlineFraction(
				for: runtimeSelection.installProgress
			),
			isActive: RuntimeInstallPresentation.showsActiveProgressEffect(
				for: runtimeSelection.installProgress
			)
		)
	}
}

private struct HUDDownloadOutline: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController

	var body: some View {
		HUDPillProgressOutline(
			progress: LauncherDownloadProgressPresentation.outlineFraction(
				for: installation.progress,
				status: lifecycle.state.presentation.status,
				hasPartialDownload: installation.hasPartialDownload,
				hasFailure: lifecycle.state.presentation.failure != nil
			),
			isActive: LauncherDownloadProgressPresentation.showsActiveProgressEffect(
				for: installation.progress,
				status: lifecycle.state.presentation.status,
				hasFailure: lifecycle.state.presentation.failure != nil
			)
		)
	}
}
