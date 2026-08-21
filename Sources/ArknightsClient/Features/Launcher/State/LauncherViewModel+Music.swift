// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

extension LauncherViewModel: BackgroundMusicContext {}

extension LauncherViewModel {
	/// Is true only while the game window is actually running, not during launcher
	/// startup and runtime preparation.
	var isGameProcessRunning: Bool {
		if case .running = phase { return true }
		return false
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
