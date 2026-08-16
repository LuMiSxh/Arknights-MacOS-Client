// SPDX-License-Identifier: MPL-2.0

import Foundation

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
	private static let userenvMarker = Data(
		"Arknights Client AppContainer compatibility".utf8)

	private let shimURL: URL?
	private let userenvURL: URL?

	init(bundle: Bundle = .main) {
		let compatibilityDirectory = bundle.resourceURL?
			.appending(path: "Compatibility", directoryHint: .isDirectory)
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
		guard try helperSupportsCompatibilityArgument(at: officialHelperURL) else {
			return false
		}
		if fileManager.contentsEqual(atPath: helperURL.path, andPath: shimURL.path) {
			return try installUserenv(
				from: userenvURL,
				beside: helperURL,
				fileManager: fileManager
			)
		}

		let temporaryURL = helperURL.deletingLastPathComponent().appending(
			path: "\(Self.shimTemporaryPrefix)\(UUID().uuidString)")
		let previousShimURL = helperURL.deletingLastPathComponent().appending(
			path: "\(Self.previousShimTemporaryPrefix)\(UUID().uuidString)")
		defer {
			try? fileManager.removeItem(at: temporaryURL)
			try? fileManager.removeItem(at: previousShimURL)
		}
		try fileManager.copyItem(at: shimURL, to: temporaryURL)
		if helperIsInstalledShim {
			try fileManager.moveItem(at: helperURL, to: previousShimURL)
		} else {
			if fileManager.fileExists(atPath: originalURL.path) {
				try fileManager.removeItem(at: originalURL)
			}
			try fileManager.moveItem(at: helperURL, to: originalURL)
		}

		do {
			try fileManager.moveItem(at: temporaryURL, to: helperURL)
			_ = try installUserenv(
				from: userenvURL,
				beside: helperURL,
				fileManager: fileManager
			)
		} catch {
			try? fileManager.removeItem(at: helperURL)
			if fileManager.fileExists(atPath: previousShimURL.path) {
				try? fileManager.moveItem(at: previousShimURL, to: helperURL)
			} else {
				try? fileManager.moveItem(at: originalURL, to: helperURL)
			}
			throw error
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
		try recoverInterruptedUserenvReplacement(beside: helperURL, fileManager: fileManager)
		try removeStaleTemporaryFiles(beside: helperURL, fileManager: fileManager)
		let removedUserenv = try removeInstalledUserenv(
			matching: userenvURL,
			beside: helperURL,
			fileManager: fileManager
		)
		guard fileManager.fileExists(atPath: originalURL.path) else {
			return removedUserenv
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
				return removedUserenv
			}
			try fileManager.removeItem(at: helperURL)
		}
		try fileManager.moveItem(at: originalURL, to: helperURL)
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
			guard try isLauncherUserenv(at: destinationURL) else {
				throw LauncherError.runtimeConfiguration(
					"The Vuplex folder contains an unknown userenv.dll. Repair the game before launching."
				)
			}
			try fileManager.moveItem(at: destinationURL, to: backupURL)
		}
		let temporaryURL = directory.appending(
			path: "\(Self.userenvTemporaryPrefix)\(UUID().uuidString)")
		defer { try? fileManager.removeItem(at: temporaryURL) }
		do {
			try fileManager.copyItem(at: sourceURL, to: temporaryURL)
			try fileManager.moveItem(at: temporaryURL, to: destinationURL)
			try? fileManager.removeItem(at: backupURL)
		} catch {
			try? fileManager.removeItem(at: destinationURL)
			if fileManager.fileExists(atPath: backupURL.path) {
				try? fileManager.moveItem(at: backupURL, to: destinationURL)
			}
			throw error
		}
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
		guard try matchesCurrent || isLauncherUserenv(at: destinationURL) else {
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
		} else if try isLauncherUserenv(at: backupURL) {
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
		let directory = helperURL.deletingLastPathComponent()
		guard fileManager.fileExists(atPath: directory.path) else { return }
		let prefixes = [
			Self.shimTemporaryPrefix,
			Self.previousShimTemporaryPrefix,
			Self.userenvTemporaryPrefix,
		]
		for url in try fileManager.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: nil
		) where prefixes.contains(where: { url.lastPathComponent.hasPrefix($0) }) {
			try fileManager.removeItem(at: url)
		}
	}

	private func isLauncherUserenv(at url: URL) throws -> Bool {
		let data = try Data(contentsOf: url, options: .mappedIfSafe)
		guard data.count <= Self.maximumShimSize else { return false }
		return data.range(of: Self.userenvMarker) != nil
	}

	private func helperSupportsCompatibilityArgument(at url: URL) throws -> Bool {
		let data = try Data(contentsOf: url, options: .mappedIfSafe)
		return data.range(of: Data(Self.compatibilityArgument.utf8)) != nil
	}

	private func helperIsLauncherShim(at url: URL) throws -> Bool {
		let data = try Data(contentsOf: url, options: .mappedIfSafe)
		guard data.count <= Self.maximumShimSize else { return false }
		if data.range(of: Self.launcherShimMarker) != nil { return true }
		let legacySignature = Data(
			Self.originalHelperName.utf16.flatMap { codeUnit in
				[UInt8(truncatingIfNeeded: codeUnit), UInt8(truncatingIfNeeded: codeUnit >> 8)]
			})
		return data.range(of: legacySignature) != nil
	}
}
