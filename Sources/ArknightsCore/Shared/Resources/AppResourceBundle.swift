// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AppResourceBundle {
	static nonisolated let bundle: Bundle = {
		#if SWIFT_PACKAGE
			if Bundle.main.bundleURL.pathExtension != "app" {
				return .module
			}
		#endif
		return .main
	}()
}
