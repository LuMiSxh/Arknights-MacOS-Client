// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	weak var model: LauncherViewModel?
	var stopGame: (() -> Void)?
	var openSettings: (() -> Void)?
	var currentBlockingPresentation: (() -> LauncherPresentationDestination?)?

	// `swift run` (used by `just preview`) launches the executable directly rather than
	// through LaunchServices: without a bundle, the process's activation policy isn't
	// guaranteed to be `.regular`, so it can render a frontmost window while keyboard
	// focus stays with whatever app was active before (the terminal, an IDE). Mouse
	// clicks still reach controls since those don't require being the active app.
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
		fixQuitMenuItemTarget()
		installQuitEventHandler()
	}

	// The main menu's Quit item ships with a nil target, which AppKit resolves by walking
	// the responder chain from the key window. While Settings (or any other sheet) is key,
	// that walk doesn't reliably reach NSApp, so Command-Q and clicking Quit in the menu bar
	// appear to do nothing until the sheet is dismissed. Pointing the item straight at NSApp
	// makes both work regardless of which window is key. The Dock icon's own Quit item and
	// external quit requests go through a different path entirely — see
	// installQuitEventHandler() below.
	private func fixQuitMenuItemTarget() {
		guard
			let item = NSApp.mainMenu?.items.lazy.compactMap({ $0.submenu }).flatMap(\.items)
				.first(where: { $0.action == #selector(NSApplication.terminate(_:)) })
		else { return }
		item.target = NSApp
	}

	func applicationWillTerminate(_ notification: Notification) {
		stopGame?()
	}

	// AppKit's own handler for the standard Quit Apple Event — what the Dock icon's own Quit
	// item and any external `tell application ... to quit` actually send — refuses the
	// request outright with a user-canceled error while a sheet is attached to the key
	// window, without ever calling applicationShouldTerminate(_:). Installing our own handler
	// for the same event lets us end the sheet first and terminate directly, bypassing that
	// built-in refusal instead of trying to work around it after the fact.
	private func installQuitEventHandler() {
		NSAppleEventManager.shared().setEventHandler(
			self,
			andSelector: #selector(handleQuitEvent(_:withReplyEvent:)),
			forEventClass: AEEventClass(kCoreEventClass),
			andEventID: AEEventID(kAEQuitApplication)
		)
	}

	// Installing this handler replaces AppKit's own default handling for the quit event
	// entirely, including whatever refusal it would otherwise apply — so every case other than
	// "nothing presented" or "Settings, and only Settings" must explicitly decline to
	// terminate here, or it would silently start quitting through dialogs that used to (or, for
	// the update prompt, always should have) blocked it. The update/failure/popup presentations
	// share this same sheet slot but carry information (an in-progress update, an error, an
	// announcement) that shouldn't be discarded just to unblock quitting — only Settings has no
	// such state. If Settings itself has something presented on top of it (a bundled document,
	// a preset gallery), that inner sheet is left alone too, and quit is declined until the user
	// closes it.
	@objc private func handleQuitEvent(
		_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor
	) {
		guard let presentation = currentBlockingPresentation?() else {
			NSApp.terminate(nil)
			return
		}
		guard
			presentation == .settings,
			let window = NSApp.windows.first(where: { $0.attachedSheet != nil }),
			let sheet = window.attachedSheet,
			sheet.attachedSheet == nil
		else { return }
		window.endSheet(sheet)
		NSApp.terminate(nil)
	}

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		let menu = NSMenu()
		menu.autoenablesItems = false
		if let model {
			let installedRegions = model.installation.installedRegions
			for region in installedRegions {
				let item = NSMenuItem(
					title: L10n.string(ApplicationStrings.play(region.localizedDisplayName)),
					action: #selector(playRegion(_:)),
					keyEquivalent: ""
				)
				item.target = self
				item.representedObject = region.rawValue
				item.isEnabled = model.canRequestDockLaunch
				menu.addItem(item)
			}
			if !installedRegions.isEmpty {
				menu.addItem(.separator())
			}
		}

		let settingsItem = NSMenuItem(
			title: L10n.string(ApplicationStrings.settings),
			action: #selector(showSettings),
			keyEquivalent: ","
		)
		settingsItem.keyEquivalentModifierMask = [.command]
		settingsItem.target = self
		settingsItem.isEnabled = openSettings != nil
		menu.addItem(settingsItem)
		return menu
	}

	@objc private func playRegion(_ sender: NSMenuItem) {
		guard
			let rawValue = sender.representedObject as? String,
			let region = GameRegion(rawValue: rawValue),
			let model
		else {
			showMainWindow()
			return
		}
		Task {
			if !(await model.launchFromDock(region: region)) {
				showMainWindow()
			}
		}
	}

	@objc private func showSettings() {
		showMainWindow()
		openSettings?()
	}

	private func showMainWindow() {
		NSApp.activate(ignoringOtherApps: true)
		let window =
			NSApp.mainWindow ?? NSApp.keyWindow
			?? NSApp.windows.first(where: \.canBecomeMain)
		window?.deminiaturize(nil)
		window?.makeKeyAndOrderFront(nil)
	}
}

@main
struct ArknightsClientApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@State private var model: LauncherViewModel

	init() {
		let arguments = ProcessInfo.processInfo.arguments
		#if DEBUG
			if DeveloperScenario(arguments: arguments) != nil {
				let root = FileManager.default.temporaryDirectory.appending(
					path: "ArknightsClientPreview",
					directoryHint: .isDirectory
				)
				let paths = AppPaths(
					applicationSupportDirectory: root.appending(path: "Support"),
					cachesDirectory: root.appending(path: "Caches"),
					libraryDirectory: root.appending(path: "Library")
				)
				let defaults = UserDefaults(suiteName: "com.lumisxh.arknights-client.preview")!
				_model = State(
					wrappedValue: LauncherViewModel(
						paths: paths,
						preferences: LauncherPreferencesStore(defaults: defaults),
						arguments: arguments
					)
				)
				return
			}
		#endif
		_model = State(wrappedValue: LauncherViewModel(arguments: arguments))
	}

	var body: some Scene {
		WindowGroup("Arknights Client") {
			GeometryReader { geometry in
				ContentView(
					model: model,
					initialMusicTitle: developerMusicTitle,
					openMusicURL: { _ = NSWorkspace.shared.open($0) },
					registerOpenSettings: { appDelegate.openSettings = $0 },
					registerQuitDismissalQuery: { appDelegate.currentBlockingPresentation = $0 }
				)
				.environment(\.launcherWindowSize, geometry.size)
			}
			.environment(\.locale, model.settings.appLanguage.locale ?? .autoupdatingCurrent)
			.frame(minWidth: 880, minHeight: 560)
			.onAppear {
				appDelegate.model = model
				appDelegate.stopGame = model.stopGameForApplicationTermination
				NSApp.activate(ignoringOtherApps: true)
			}
		}
		.windowStyle(.hiddenTitleBar)
		.defaultSize(width: 1040, height: 680)
	}

	#if DEBUG
		private var developerMusicTitle: String? {
			model.developerAccessibilityMusicTitle
		}
	#else
		private var developerMusicTitle: String? { nil }
	#endif
}
