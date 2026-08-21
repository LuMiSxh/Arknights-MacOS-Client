// SPDX-License-Identifier: MPL-2.0

import Foundation

enum BackgroundMusicOperationKind {
	case trackChange
	case playbackChange(PlaybackIntent)
}
