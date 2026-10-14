// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

/// Draws the control bar surface and its download outline.
///
/// This leaf is the only HUD view that reads the per-tick `installation.progress`,
/// so progress updates do not invalidate the parent's body. The parent builds `content`.
struct HUDProgressSurface<Content: View>: View {
	package let lifecycle: LauncherLifecycleStore
	package let installation: InstallationController
	let tint: Color
	let progressTint: Color
	@ViewBuilder package let content: () -> Content

	var body: some View {
		content()
			.hudPillSurface(
				progress: LauncherDownloadProgressPresentation.outlineFraction(
					for: installation.progress,
					status: lifecycle.state.presentation.status,
					hasPartialDownload: installation.hasPartialDownload,
					hasFailure: lifecycle.state.presentation.failure != nil
				),
				isProgressActive: LauncherDownloadProgressPresentation.showsActiveProgressEffect(
					for: installation.progress,
					status: lifecycle.state.presentation.status,
					hasFailure: lifecycle.state.presentation.failure != nil
				),
				tint: tint,
				progressTint: progressTint
			)
	}
}
