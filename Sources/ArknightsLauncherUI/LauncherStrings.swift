// SPDX-License-Identifier: MPL-2.0

enum LauncherStrings {
	static let popupDone = "Done"
	static let updateDone = "Done"
	static let updateInstalling = "Finishing update…"
	static let updateErrorDetail = "The update could not be completed."

	static func serverReset(hours: Int, minutes: Int) -> String {
		let minuteText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
		return "Reset in \(hours)h \(minuteText)m"
	}
}
