// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

extension CustomizationController {
	func chooseCustomAppIcon() {
		chooseCustomIcon(
			title: LauncherStrings.pickerLauncherIcon,
			apply: applyCustomAppIcon(from:)
		)
	}

	func chooseCustomGameIcon() {
		chooseCustomIcon(
			title: LauncherStrings.pickerGameIcon,
			apply: applyCustomGameIcon(from:)
		)
	}

	func resetGameIcon() {
		invalidateIconOperations()
		do {
			if FileManager.default.fileExists(atPath: paths.customGameIcon.path) {
				try FileManager.default.removeItem(at: paths.customGameIcon)
			}
			try CustomizationImageIO.removeIfPresent(paths.operatorPresetAvatar)
			setHasCustomGameIcon(false)
		} catch {
			lifecycle.show(error)
		}
	}

	func resetAppIcon() {
		invalidateIconOperations()
		do {
			if FileManager.default.fileExists(atPath: paths.customAppIcon.path) {
				try FileManager.default.removeItem(at: paths.customAppIcon)
			}
			try CustomizationImageIO.removeIfPresent(paths.operatorPresetAvatar)
			guard launcherIconManager.reset() else { throw LauncherError.cannotSetAppIcon }
			setHasCustomAppIcon(false)
			updateThemeColor()
		} catch {
			lifecycle.show(error)
		}
	}

	@discardableResult
	func loadCustomAppIcon() async -> Bool {
		guard let (operationID, generation) = beginIconRestore() else { return false }
		let iconURL = paths.customAppIcon
		guard isCurrentIconRestore(operationID, generation: generation) else { return false }
		setHasCustomGameIcon(FileManager.default.fileExists(atPath: paths.customGameIcon.path))
		do {
			let data = try await dataLoader(iconURL)
			guard isCurrentIconRestore(operationID, generation: generation) else { return false }
			guard let image = NSImage(data: data) else {
				await log.error("Saved launcher icon is not a valid image")
				setHasCustomAppIcon(false)
				return false
			}
			guard launcherIconManager.apply(image) else {
				await log.error("Failed to reapply the saved launcher icon to the app bundle")
				setHasCustomAppIcon(false)
				return false
			}
			guard isCurrentIconRestore(operationID, generation: generation) else { return false }
			setHasCustomAppIcon(true)
			return true
		} catch {
			guard isCurrentIconRestore(operationID, generation: generation) else { return false }
			setHasCustomAppIcon(false)
			if (error as? CocoaError)?.code == .fileReadNoSuchFile { return false }
			await log.error("Failed to load saved launcher icon: \(error.localizedDescription)")
			return false
		}
	}

	func resetOperatorIcons() {
		invalidateIconOperations()
		do {
			for url in [paths.customAppIcon, paths.customGameIcon, paths.operatorPresetAvatar]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
			guard launcherIconManager.reset() else { throw LauncherError.cannotSetAppIcon }
			setHasCustomAppIcon(false)
			setHasCustomGameIcon(false)
			updateThemeColor()
		} catch {
			lifecycle.show(error)
		}
	}

	func refreshOperatorPresetIconsForTheme(hue: Double?) async {
		await startOperatorPresetIconRefresh(hue: hue).value
	}

	@discardableResult
	func startOperatorPresetIconRefresh(hue: Double?) -> Task<Void, Never> {
		guard !iconMutationInFlight else { return Task {} }
		let operationID = UUID()
		passiveOperatorIconOperationID = operationID
		let generation = iconMutationGeneration
		let sourceURL = paths.operatorPresetAvatar
		let dataLoader = self.dataLoader
		return Task { [weak self, log] in
			guard let self else { return }
			do {
				let data = try await dataLoader(sourceURL)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				guard
					let icons = AppIconRenderer.createPresetIconPair(
						from: data,
						accentHue: hue
					),
					let launcherTIFF = icons.launcher.tiffRepresentation,
					let gameTIFF = icons.game.tiffRepresentation
				else { throw LauncherError.cannotEncodeAppIcon }
				async let launcherPNG = CustomizationImageIO.encodePNG(fromTIFF: launcherTIFF)
				async let gamePNG = CustomizationImageIO.encodePNG(fromTIFF: gameTIFF)
				let encodedIcons = try await (launcherPNG, gamePNG)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				let launcherStage = CustomizationImageIO.stagedURL(
					for: self.paths.customAppIcon,
					operationID: operationID
				)
				let gameStage = CustomizationImageIO.stagedURL(
					for: self.paths.customGameIcon,
					operationID: operationID
				)
				try await self.dataStager(encodedIcons.0, launcherStage)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else {
					CustomizationImageIO.discard(launcherStage, log: log)
					return
				}
				try await self.dataStager(encodedIcons.1, gameStage)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else {
					CustomizationImageIO.discard(launcherStage, log: log)
					CustomizationImageIO.discard(gameStage, log: log)
					return
				}
				try CustomizationImageIO.commit(launcherStage, to: self.paths.customAppIcon)
				try CustomizationImageIO.commit(gameStage, to: self.paths.customGameIcon)
				guard self.launcherIconManager.apply(icons.launcher) else {
					throw LauncherError.cannotSetAppIcon
				}
				self.setHasCustomAppIcon(true)
				self.setHasCustomGameIcon(true)
			} catch {
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				if (error as? CocoaError)?.code == .fileReadNoSuchFile { return }
				await log.error(
					"Failed to refresh operator icons for Dynamic Theme: \(error.localizedDescription)"
				)
			}
			guard self.passiveOperatorIconOperationID == operationID else { return }
			self.passiveOperatorIconOperationID = nil
		}
	}

	private func chooseCustomIcon(
		title: LocalizedStringResource,
		apply: @escaping (URL) -> Void
	) {
		let panel = NSOpenPanel()
		panel.title = L10n.string(title)
		panel.prompt = L10n.string(LauncherStrings.pickerChoose)
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		apply(selected)
	}

	private func beginIconRestore() -> (UUID, UInt64)? {
		guard !iconMutationInFlight else { return nil }
		let operationID = UUID()
		iconRestoreOperationID = operationID
		return (operationID, iconMutationGeneration)
	}

	private func isCurrentIconRestore(_ operationID: UUID, generation: UInt64) -> Bool {
		iconRestoreOperationID == operationID
			&& iconMutationGeneration == generation
			&& !iconMutationInFlight
			&& !Task.isCancelled
	}

	private func isCurrentPassiveOperatorIconRefresh(
		_ operationID: UUID,
		generation: UInt64
	) -> Bool {
		passiveOperatorIconOperationID == operationID
			&& iconMutationGeneration == generation
			&& !iconMutationInFlight
			&& !Task.isCancelled
	}

	func invalidateIconOperations() {
		iconMutationGeneration &+= 1
		iconMutationInFlight = false
		iconRestoreOperationID = nil
		passiveOperatorIconOperationID = nil
		operatorIconOperationID = UUID()
	}

	func applyCustomAppIcon(from url: URL) {
		let id = beginIconOperation()
		loadAndApplyCustomIcon(from: url, operationID: id, isAppIcon: true)
	}
	func applyCustomGameIcon(from url: URL) {
		let id = beginIconOperation()
		loadAndApplyCustomIcon(from: url, operationID: id, isAppIcon: false)
	}
	func applyPresetAvatar(data: Data) async {
		let id = beginIconOperation()
		let source = paths.operatorPresetAvatar
		do {
			try await Task.detached(priority: .userInitiated) {
				try CustomizationImageIO.validate(data, source: source)
			}.value
			guard operatorIconOperationID == id,
				let icons = AppIconRenderer.createPresetIconPair(
					from: data, accentHue: dynamicThemeHue),
				let launcherTIFF = icons.launcher.tiffRepresentation,
				let gameTIFF = icons.game.tiffRepresentation
			else { throw LauncherError.cannotEncodeAppIcon }
			async let launcher = CustomizationImageIO.encodePNG(fromTIFF: launcherTIFF)
			async let game = CustomizationImageIO.encodePNG(fromTIFF: gameTIFF)
			let encoded = try await (launcher, game)
			guard operatorIconOperationID == id else { return }
			let app = CustomizationImageIO.stagedURL(for: paths.customAppIcon, operationID: id)
			let gameURL = CustomizationImageIO.stagedURL(for: paths.customGameIcon, operationID: id)
			let sourceURL = CustomizationImageIO.stagedURL(for: source, operationID: id)
			try await dataStager(encoded.0, app)
			guard operatorIconOperationID == id else {
				CustomizationImageIO.discard(app, log: log)
				return
			}
			try await dataStager(encoded.1, gameURL)
			guard operatorIconOperationID == id else {
				CustomizationImageIO.discard(app, log: log)
				CustomizationImageIO.discard(gameURL, log: log)
				return
			}
			try await dataStager(data, sourceURL)
			guard operatorIconOperationID == id else {
				for url in [app, gameURL, sourceURL] {
					CustomizationImageIO.discard(url, log: log)
				}
				return
			}
			try CustomizationImageIO.commit(app, to: paths.customAppIcon)
			try CustomizationImageIO.commit(gameURL, to: paths.customGameIcon)
			try CustomizationImageIO.commit(sourceURL, to: source)
			guard launcherIconManager.apply(icons.launcher) else {
				throw LauncherError.cannotSetAppIcon
			}
			setHasCustomAppIcon(true)
			setHasCustomGameIcon(true)
		} catch {
			guard operatorIconOperationID == id else { return }
			lifecycle.show(error)
		}
		finishIconMutation(id)
	}
	private func loadAndApplyCustomIcon(from url: URL, operationID id: UUID, isAppIcon: Bool) {
		let load = dataLoader
		Task { [weak self] in
			guard let self else { return }
			defer { self.finishIconMutation(id) }
			do {
				let data = try await load(url)
				guard self.operatorIconOperationID == id else { return }
				guard let raw = NSImage(data: data) else {
					self.lifecycle.show(LauncherError.invalidCustomImage(url))
					return
				}
				try CustomizationImageIO.removeIfPresent(self.paths.operatorPresetAvatar)
				await self.persistCustomIcon(
					AppIconRenderer.padToAppleGrid(image: raw), operationID: id,
					isAppIcon: isAppIcon)
			} catch {
				guard self.operatorIconOperationID == id else { return }
				self.lifecycle.show(error)
			}
		}
	}

	private func persistCustomIcon(_ image: NSImage, operationID id: UUID, isAppIcon: Bool) async {
		do {
			guard let tiff = image.tiffRepresentation else {
				throw LauncherError.cannotEncodeAppIcon
			}
			let png = try await CustomizationImageIO.encodePNG(fromTIFF: tiff)
			guard operatorIconOperationID == id else { return }
			let destination = isAppIcon ? paths.customAppIcon : paths.customGameIcon
			let staged = CustomizationImageIO.stagedURL(for: destination, operationID: id)
			try await dataStager(png, staged)
			guard operatorIconOperationID == id else {
				CustomizationImageIO.discard(staged, log: log)
				return
			}
			try CustomizationImageIO.commit(staged, to: destination)
			if isAppIcon {
				guard launcherIconManager.apply(image) else { throw LauncherError.cannotSetAppIcon }
				setHasCustomAppIcon(true)
			} else {
				setHasCustomGameIcon(true)
			}
		} catch {
			guard operatorIconOperationID == id else { return }
			lifecycle.show(error)
		}
	}
	private func beginIconOperation() -> UUID {
		let id = UUID()
		operatorIconOperationID = id
		passiveOperatorIconOperationID = nil
		iconRestoreOperationID = nil
		iconMutationGeneration &+= 1
		iconMutationInFlight = true
		return id
	}
	private func finishIconMutation(_ id: UUID) {
		guard operatorIconOperationID == id else { return }
		iconMutationInFlight = false
	}
}
