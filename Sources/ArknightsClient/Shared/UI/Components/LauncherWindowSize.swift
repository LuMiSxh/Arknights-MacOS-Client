// SPDX-License-Identifier: MPL-2.0

import SwiftUI

private struct LauncherWindowSizeKey: EnvironmentKey {
	static let defaultValue: CGSize? = nil
}

extension EnvironmentValues {
	var launcherWindowSize: CGSize? {
		get { self[LauncherWindowSizeKey.self] }
		set { self[LauncherWindowSizeKey.self] = newValue }
	}
}
