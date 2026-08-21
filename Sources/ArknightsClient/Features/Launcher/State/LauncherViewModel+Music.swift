// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import YouTubePlayerKit

extension LauncherViewModel: BackgroundMusicContext {}

extension LauncherViewModel {
	func openCurrentMusicURL() {
		if let currentMusicVideoID,
			let url = URL(string: "https://www.youtube.com/watch?v=\(currentMusicVideoID)")
		{
			NSWorkspace.shared.open(url)
			return
		}
		let trimmed = launcherMusicURL.trimmingCharacters(in: .whitespacesAndNewlines)
		if let url = URL(string: trimmed) { NSWorkspace.shared.open(url) }
	}

	/// Is true only while the game window is actually running, not during launcher
	/// startup and runtime preparation.
	var isGameProcessRunning: Bool {
		state.activity.isGameProcessRunning
	}

	var parsedYouTubeSource: YouTubePlayer.Source? {
		let trimmedURL = launcherMusicURL.trimmingCharacters(in: .whitespacesAndNewlines)
		guard
			let url = URL(string: trimmedURL),
			let host = url.host?.lowercased()
		else { return nil }

		if host.contains("youtube.com") || host.contains("youtu.be") {
			if let listID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
				.queryItems?.first(where: { $0.name == "list" })?.value
			{
				return .playlist(id: listID)
			}
			if host.contains("youtu.be") {
				return .video(id: url.lastPathComponent)
			}
			if let videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
				.queryItems?.first(where: { $0.name == "v" })?.value
			{
				return .video(id: videoID)
			}
		}
		return .init(url: url)
	}
}
