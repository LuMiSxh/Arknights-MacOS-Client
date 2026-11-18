// SPDX-License-Identifier: MPL-2.0

import ArknightsGameInstallation
import SwiftUI

extension View {
	/// Explains a refused install folder, or asks before the launcher uses a folder with files.
	func installDirectoryConfirmation(_ installation: InstallationController) -> some View {
		modifier(InstallDirectoryConfirmationModifier(installation: installation))
	}
}

private struct InstallDirectoryConfirmationModifier: ViewModifier {
	let installation: InstallationController

	func body(content: Content) -> some View {
		let pending = installation.pendingInstallDirectory
		content.confirmationDialog(
			pending.map { title(for: $0.issue) } ?? "",
			isPresented: Binding(
				get: { pending != nil },
				set: { isPresented in
					if !isPresented { installation.dismissPendingInstallDirectory() }
				}
			),
			titleVisibility: .visible
		) {
			if let pending, !pending.issue.isRefusal {
				Button("Use Folder Anyway", action: installation.confirmPendingInstallDirectory)
				Button("Cancel", role: .cancel) {}
			} else {
				Button("OK", role: .cancel) {}
			}
		} message: {
			Text(pending.map { message(for: $0.issue) } ?? "")
		}
	}

	private func title(for issue: InstallDirectoryIssue) -> String {
		switch issue {
		case .overlapsOtherServer, .holdsLauncherData: "Choose a Different Folder"
		case .hasFiles: "Use This Folder?"
		}
	}

	private func message(for issue: InstallDirectoryIssue) -> String {
		switch issue {
		case .overlapsOtherServer(let region):
			"This folder overlaps the game files for \(region.displayName). Each server needs its own folder."
		case .holdsLauncherData:
			"The launcher keeps its data inside this folder. Choose a folder for the game files only."
		case .hasFiles:
			"Arknights files are added to this folder. Uninstalling removes only the game files."
		}
	}
}
