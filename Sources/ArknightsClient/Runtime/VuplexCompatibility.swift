// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Swaps the embedded browser's helper with one that disables accelerated paint and stubs
/// `userenv.dll`, working around a Wine AppContainer gap that otherwise crashes Chromium's
/// sandbox during OAuth and payment-provider popups.
struct VuplexCompatibility: GameCompatibilityComponent {
	let identifier = "vuplex-webview"
	static let helperRelativePath =
		"Arknights_Data/Plugins/x86_64/VuplexWebViewChromium/Vuplex WebView.vuplex"
	static let originalHelperName = "Vuplex WebView.original.helper.vuplex"
	static let compatibilityArgument = "vx-accelerated-paint-disabled"
	static let userenvName = "userenv.dll"
	static let launcherShimMarker = Data("Arknights Client Vuplex compatibility".utf8)
	private static let maximumShimSize = 1_048_576
	private static let shimTemporaryPrefix = ".arknights-client-vuplex-shim-"
	private static let previousShimTemporaryPrefix = ".arknights-client-vuplex-previous-"
	private static let userenvTemporaryPrefix = ".arknights-client-userenv-"
	private static let userenvBackupName = ".arknights-client-userenv.previous.dll"
	private static let retiredSoftwareFallbackName =
		".arknights-client-vuplex-software-rendering"
	private static let userenvMarker = Data(
		"Arknights Client AppContainer compatibility".utf8)

	private let shimURL: URL?
	private let userenvURL: URL?

	init(bundle: Bundle = .main) {
		let compatibilityDirectory = bundle.resourceURL?
			.appending(path: "Compatibility/Vuplex", directoryHint: .isDirectory)
		shimURL = compatibilityDirectory?.appending(path: "Vuplex WebView.vuplex")
		userenvURL = compatibilityDirectory?.appending(path: Self.userenvName)
	}

	init(shimURL: URL?, userenvURL: URL?) {
		self.shimURL = shimURL
		self.userenvURL = userenvURL
	}

	@discardableResult
	func installIfSupported(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let helperURL = gameDirectory.appending(path: Self.helperRelativePath)
		let originalURL = helperURL.deletingLastPathComponent().appending(
			path: Self.originalHelperName)
		_ = try removeRetiredSoftwareFallback(beside: helperURL, fileManager: fileManager)
		try recoverInterruptedUserenvReplacement(beside: helperURL, fileManager: fileManager)
		try removeStaleTemporaryFiles(beside: helperURL, fileManager: fileManager)
		guard
			let shimURL,
			let userenvURL,
			fileManager.fileExists(atPath: shimURL.path),
			fileManager.fileExists(atPath: userenvURL.path)
		else {
			return false
		}

		if !fileManager.fileExists(atPath: helperURL.path),
			fileManager.fileExists(atPath: originalURL.path)
		{
			try fileManager.moveItem(at: originalURL, to: helperURL)
		}

		guard fileManager.fileExists(atPath: helperURL.path) else { return false }
		let helperIsInstalledShim = try helperIsLauncherShim(at: helperURL)
		let officialHelperURL = helperIsInstalledShim ? originalURL : helperURL
		if helperIsInstalledShim,
			!fileManager.fileExists(atPath: officialHelperURL.path)
		{
			throw LauncherError.runtimeConfiguration(
				"The official Vuplex helper is missing. Repair the game before launching."
			)
		}
		guard
			try GameShimIO.containsMarker(
				at: officialHelperURL,
				marker: Data(Self.compatibilityArgument.utf8)
			)
		else {
			return false
		}
		if fileManager.contentsEqual(atPath: helperURL.path, andPath: shimURL.path) {
			return try installUserenv(
				from: userenvURL,
				beside: helperURL,
				fileManager: fileManager
			)
		}

		try GameShimIO.swapHelper(
			at: helperURL,
			with: shimURL,
			backupURL: originalURL,
			isCurrentlyInstalledShim: helperIsInstalledShim,
			temporaryPrefix: Self.shimTemporaryPrefix,
			previousPrefix: Self.previousShimTemporaryPrefix,
			fileManager: fileManager
		) {
			_ = try installUserenv(from: userenvURL, beside: helperURL, fileManager: fileManager)
		}
		return true
	}

	@discardableResult
	func restoreIfInstalled(
		in gameDirectory: URL,
		fileManager: FileManager = .default
	) throws -> Bool {
		let helperURL = gameDirectory.appending(path: Self.helperRelativePath)
		let originalURL = helperURL.deletingLastPathComponent().appending(
			path: Self.originalHelperName)
		let removedSoftwareFallback = try removeRetiredSoftwareFallback(
			beside: helperURL,
			fileManager: fileManager
		)
		try recoverInterruptedUserenvReplacement(beside: helperURL, fileManager: fileManager)
		try removeStaleTemporaryFiles(beside: helperURL, fileManager: fileManager)
		let removedUserenv = try removeInstalledUserenv(
			matching: userenvURL,
			beside: helperURL,
			fileManager: fileManager
		)
		guard fileManager.fileExists(atPath: originalURL.path) else {
			return removedUserenv || removedSoftwareFallback
		}

		if fileManager.fileExists(atPath: helperURL.path) {
			let matchesCurrentShim =
				shimURL.map {
					fileManager.fileExists(atPath: $0.path)
						&& fileManager.contentsEqual(atPath: helperURL.path, andPath: $0.path)
				} ?? false
			let matchesPreviousShim = try helperIsLauncherShim(at: helperURL)
			let isInstalledShim = matchesCurrentShim || matchesPreviousShim
			guard isInstalledShim else {
				// The official updater has already replaced the shim. Its current helper wins.
				try fileManager.removeItem(at: originalURL)
				return removedUserenv || removedSoftwareFallback
			}
			try fileManager.removeItem(at: helperURL)
		}
		try fileManager.moveItem(at: originalURL, to: helperURL)
		return true
	}

	private func removeRetiredSoftwareFallback(
		beside helperURL: URL,
		fileManager: FileManager
	) throws -> Bool {
		let markerURL = helperURL.deletingLastPathComponent().appending(
			path: Self.retiredSoftwareFallbackName)
		let values = try? markerURL.resourceValues(forKeys: [.isRegularFileKey])
		guard values?.isRegularFile == true else { return false }
		try fileManager.removeItem(at: markerURL)
		return true
	}

	private func installUserenv(
		from sourceURL: URL,
		beside helperURL: URL,
		fileManager: FileManager
	) throws -> Bool {
		let directory = helperURL.deletingLastPathComponent()
		let destinationURL = directory.appending(path: Self.userenvName)
		let backupURL = directory.appending(path: Self.userenvBackupName)
		try recoverInterruptedUserenvReplacement(beside: helperURL, fileManager: fileManager)
		if fileManager.fileExists(atPath: destinationURL.path) {
			if fileManager.contentsEqual(atPath: destinationURL.path, andPath: sourceURL.path) {
				return false
			}
			guard
				try GameShimIO.containsMarker(
					at: destinationURL,
					marker: Self.userenvMarker,
					maximumSize: Self.maximumShimSize
				)
			else {
				throw LauncherError.runtimeConfiguration(
					"The Vuplex folder contains an unknown userenv.dll. Repair the game before launching."
				)
			}
			try fileManager.moveItem(at: destinationURL, to: backupURL)
		}
		try GameShimIO.replaceWithBackup(
			destinationURL: destinationURL,
			sourceURL: sourceURL,
			backupURL: backupURL,
			temporaryName: "\(Self.userenvTemporaryPrefix)\(UUID().uuidString)",
			fileManager: fileManager
		)
		return true
	}

	private func removeInstalledUserenv(
		matching sourceURL: URL?,
		beside helperURL: URL,
		fileManager: FileManager
	) throws -> Bool {
		let destinationURL = helperURL.deletingLastPathComponent().appending(
			path: Self.userenvName)
		guard fileManager.fileExists(atPath: destinationURL.path) else { return false }
		let matchesCurrent =
			sourceURL.map {
				fileManager.fileExists(atPath: $0.path)
					&& fileManager.contentsEqual(atPath: destinationURL.path, andPath: $0.path)
			} ?? false
		guard
			try matchesCurrent
				|| GameShimIO.containsMarker(
					at: destinationURL,
					marker: Self.userenvMarker,
					maximumSize: Self.maximumShimSize
				)
		else {
			return false
		}
		try fileManager.removeItem(at: destinationURL)
		return true
	}

	private func recoverInterruptedUserenvReplacement(
		beside helperURL: URL,
		fileManager: FileManager
	) throws {
		let directory = helperURL.deletingLastPathComponent()
		let destinationURL = directory.appending(path: Self.userenvName)
		let backupURL = directory.appending(path: Self.userenvBackupName)
		guard fileManager.fileExists(atPath: backupURL.path) else { return }
		if !fileManager.fileExists(atPath: destinationURL.path) {
			try fileManager.moveItem(at: backupURL, to: destinationURL)
		} else if try GameShimIO.containsMarker(
			at: backupURL,
			marker: Self.userenvMarker,
			maximumSize: Self.maximumShimSize
		) {
			try fileManager.removeItem(at: backupURL)
		} else {
			throw LauncherError.runtimeConfiguration(
				"The Vuplex folder contains an unknown compatibility backup. Repair the game before launching."
			)
		}
	}

	private func removeStaleTemporaryFiles(
		beside helperURL: URL,
		fileManager: FileManager
	) throws {
		try GameShimIO.removeStaleTemporaryFiles(
			in: helperURL.deletingLastPathComponent(),
			matchingPrefixes: [
				Self.shimTemporaryPrefix,
				Self.previousShimTemporaryPrefix,
				Self.userenvTemporaryPrefix,
			],
			fileManager: fileManager
		)
	}

	private func helperIsLauncherShim(at url: URL) throws -> Bool {
		if try GameShimIO.containsMarker(
			at: url,
			marker: Self.launcherShimMarker,
			maximumSize: Self.maximumShimSize
		) {
			return true
		}
		let legacySignature = Data(
			Self.originalHelperName.utf16.flatMap { codeUnit in
				[UInt8(truncatingIfNeeded: codeUnit), UInt8(truncatingIfNeeded: codeUnit >> 8)]
			})
		return try GameShimIO.containsMarker(
			at: url,
			marker: legacySignature,
			maximumSize: Self.maximumShimSize
		)
	}
}
