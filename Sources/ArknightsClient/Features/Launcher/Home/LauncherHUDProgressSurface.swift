// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// Draws the control bar surface and its download outline.
///
/// This leaf is the only HUD view that reads the per-tick `installation.progress`,
/// so progress updates do not invalidate the parent's body. The parent builds `content`.
struct HUDProgressSurface<Content: View>: View {
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let tint: Color
	let progressTint: Color
	@ViewBuilder let content: () -> Content

	var body: some View {
		content()
			.hudPillSurface(
				progress: LauncherDownloadProgressPresentation.outlineFraction(
					for: installation.progress,
					status: lifecycle.presentation.status,
					hasPartialDownload: installation.hasPartialDownload,
					hasFailure: lifecycle.failure != nil
				),
				isProgressActive: LauncherDownloadProgressPresentation.showsActiveProgressEffect(
					for: installation.progress,
					status: lifecycle.presentation.status,
					hasFailure: lifecycle.failure != nil
				),
				tint: tint,
				progressTint: progressTint
			)
	}
}
