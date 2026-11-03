// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherPopupContent {
	case markdown(String)
	case attributed(AttributedString)
}

struct LauncherPopup: Identifiable {
	let id: String
	let title: String
	let content: LauncherPopupContent
	let dismissTitle: String
	let actionTitle: String?
	let actionURL: URL?
}
