// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The bundled Wine runtime is an Intel binary (see README); without Rosetta 2, launching
/// it triggers macOS's own (easy to miss) installer prompt, which silently eats the
/// window-readiness timeout instead of failing fast.
enum RosettaAvailability {
	static func isInstalled(fileManager: FileManager = .default) -> Bool {
		fileManager.fileExists(atPath: "/Library/Apple/usr/share/rosetta/rosetta")
	}
}
