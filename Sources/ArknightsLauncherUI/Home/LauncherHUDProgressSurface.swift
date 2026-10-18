// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

// The surface and `content` read only state that changes on transitions. The outline overlay
// is the only view that reads the per-tick `installation.progress`, so progress updates
// do not invalidate `content`. While an outline is possible, the overlay draws the border.
struct HUDProgressSurface<Content: View>: View {
	package let lifecycle: LauncherLifecycleStore
	package let installation: InstallationController
	let tint: Color
	let progressTint: Color
	@ViewBuilder package let content: () -> Content

	var body: some View {
		let supportsOutline = LauncherDownloadProgressPresentation.supportsOutline(
			status: lifecycle.state.presentation.status,
			hasPartialDownload: installation.hasPartialDownload,
			hasFailure: lifecycle.state.presentation.failure != nil
		)
		content()
			.hudPillSurface(showsBorder: !supportsOutline, tint: tint)
			.overlay {
				if supportsOutline {
					HUDDownloadOutline(
						lifecycle: lifecycle,
						installation: installation,
						tint: progressTint
					)
				}
			}
	}
}

private struct HUDDownloadOutline: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let tint: Color

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
			),
			tint: tint
		)
	}
}
