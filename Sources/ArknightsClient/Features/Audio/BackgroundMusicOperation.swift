// SPDX-License-Identifier: MPL-2.0

import Foundation

enum BackgroundMusicOperation {
	case idle
	case trackChange(BackgroundMusicOperationToken)
	case playbackChange(BackgroundMusicOperationToken, PlaybackIntent)

	var isChangingTrack: Bool {
		if case .trackChange = self { return true }
		return false
	}

	var isChangingPlayback: Bool {
		if case .playbackChange = self { return true }
		return false
	}

	var token: BackgroundMusicOperationToken? {
		switch self {
		case .idle:
			nil
		case .trackChange(let token), .playbackChange(let token, _):
			token
		}
	}
}
