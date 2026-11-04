// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Swaps the embedded browser's helper with one that disables accelerated paint, working
// around a shared-texture conflict between Chromium and DXMT during OAuth and
// payment-provider popups.
struct VuplexCompatibility: GameCompatibilityComponent {
	let identifier = "vuplex-webview"
	static let helperRelativePath =
		"Arknights_Data/Plugins/x86_64/VuplexWebViewChromium/Vuplex WebView.vuplex"
	static let originalHelperName = "Vuplex WebView.original.helper.vuplex"
	static let compatibilityArgument = "vx-accelerated-paint-disabled"
	/// Earlier launchers installed this stub for AppContainer APIs. The bundled runtime
	/// provides them, so the component only removes a copy that carries the launcher marker.
	static let legacyUserenvName = "userenv.dll"
	static let launcherShimMarker = Data("Arknights Client Vuplex compatibility".utf8)
	private static let shimTemporaryPrefix = ".arknights-client-vuplex-shim-"
	private static let previousShimTemporaryPrefix = ".arknights-client-vuplex-previous-"
	private static let legacyUserenvTemporaryPrefix = ".arknights-client-userenv-"
	private static let legacyUserenvBackupName = ".arknights-client-userenv.previous.dll"
	private static let retiredSoftwareFallbackName =
		".arknights-client-vuplex-software-rendering"
	private static let legacyUserenvMarker = Data(
		"Arknights Client AppContainer compatibility".utf8)

	private let shimURL: URL?
	private let log: LauncherLog?

	init(bundle: Bundle = .main, log: LauncherLog? = nil) {
		self.log = log
		let compatibilityDirectory = bundle.resourceURL.map(BundledResource.compatibility.location)?
			.appending(path: "Vuplex", directoryHint: .isDirectory)
		shimURL = compatibilityDirectory?.appending(path: "Vuplex WebView.vuplex")
	}

	init(shimURL: URL?, log: LauncherLog? = nil) {
		self.shimURL = shimURL
		self.log = log
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
		_ = removeLegacyUserenv(beside: helperURL, fileManager: fileManager)
		try removeStaleTemporaryFiles(beside: helperURL, fileManager: fileManager)
		guard let shimURL, fileManager.fileExists(atPath: shimURL.path) else {
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
			throw GameCompatibilityError.setupFailed(
				"The official Vuplex helper is missing. Repair the game before launching."
			)
		}
		guard
			try GameShimIO.containsMarker(
				at: officialHelperURL,
				marker: Data(Self.compatibilityArgument.utf8),
				maximumSize: AppConstants.Game.vuplexOfficialHelperMaximumBytes
			)
		else {
			return false
		}
		if fileManager.contentsEqual(atPath: helperURL.path, andPath: shimURL.path) {
			return false
		}

		try GameShimIO.swapHelper(
			at: helperURL,
			with: shimURL,
			backupURL: originalURL,
			isCurrentlyInstalledShim: helperIsInstalledShim,
			temporaryPrefix: Self.shimTemporaryPrefix,
			previousPrefix: Self.previousShimTemporaryPrefix,
			fileManager: fileManager,
			log: log
		) {
			// The shim has no companion files.
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
		let removedLegacyUserenv = removeLegacyUserenv(
			beside: helperURL,
			fileManager: fileManager
		)
		try removeStaleTemporaryFiles(beside: helperURL, fileManager: fileManager)
		let removedLegacyFiles = removedLegacyUserenv || removedSoftwareFallback
		guard fileManager.fileExists(atPath: originalURL.path) else {
			return removedLegacyFiles
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
				return removedLegacyFiles
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
		let values: URLResourceValues
		do {
			values = try markerURL.resourceValues(forKeys: [.isRegularFileKey])
		} catch let error as CocoaError
			where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		{
			return false
		}
		guard values.isRegularFile == true else { return false }
		try fileManager.removeItem(at: markerURL)
		return true
	}

	private func removeLegacyUserenv(
		beside helperURL: URL,
		fileManager: FileManager
	) -> Bool {
		let directory = helperURL.deletingLastPathComponent()
		var removed = false
		for name in [Self.legacyUserenvName, Self.legacyUserenvBackupName] {
			let url = directory.appending(path: name)
			guard fileManager.fileExists(atPath: url.path) else { continue }
			GameShimIO.attempt("Could not remove a legacy userenv file", log: log) {
				guard
					try GameShimIO.containsMarker(
						at: url,
						marker: Self.legacyUserenvMarker,
						maximumSize: AppConstants.Game.vuplexShimMaximumBytes
					)
				else { return }
				try fileManager.removeItem(at: url)
				removed = true
			}
		}
		return removed
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
				Self.legacyUserenvTemporaryPrefix,
			],
			fileManager: fileManager
		)
	}

	private func helperIsLauncherShim(at url: URL) throws -> Bool {
		if try GameShimIO.containsMarker(
			at: url,
			marker: Self.launcherShimMarker,
			maximumSize: AppConstants.Game.vuplexShimMaximumBytes
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
			maximumSize: AppConstants.Game.vuplexShimMaximumBytes
		)
	}
}
