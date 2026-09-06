// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	weak var model: LauncherViewModel?
	var stopGame: (() -> Void)?
	var openSettings: (() -> Void)?
	var blockingPresentationForQuit: (() -> LauncherPresentationDestination?)?
	var dismissSettingsForQuit: (() -> Void)?
	private var quitKeyMonitor: Any?

	// `swift run` (used by `just preview`) launches the executable directly rather than
	// through LaunchServices: without a bundle, the process's activation policy isn't
	// guaranteed to be `.regular`, so it can render a frontmost window while keyboard
	// focus stays with whatever app was active before (the terminal, an IDE). Mouse
	// clicks still reach controls since those don't require being the active app.
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)
		fixQuitMenuItemTarget()
		installQuitKeyMonitor()
		installQuitEventHandler()
	}

	// A key SwiftUI sheet can prevent the default nil target from reaching NSApp.
	private func fixQuitMenuItemTarget() {
		guard
			let item = NSApp.mainMenu?.items.lazy.compactMap({ $0.submenu }).flatMap(\.items)
				.first(where: { $0.action == #selector(NSApplication.terminate(_:)) })
		else { return }
		item.target = self
		item.action = #selector(requestQuit)
	}

	// A key sheet can also bypass the menu item's Command-Q dispatch.
	private func installQuitKeyMonitor() {
		quitKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
				event.charactersIgnoringModifiers?.lowercased() == "q"
			else { return event }
			self?.requestQuit()
			return nil
		}
	}

	func applicationWillTerminate(_ notification: Notification) {
		stopGame?()
	}

	// AppKit rejects quit Apple Events with an attached sheet before delegate policy runs.
	private func installQuitEventHandler() {
		NSAppleEventManager.shared().setEventHandler(
			self,
			andSelector: #selector(handleQuitEvent(_:withReplyEvent:)),
			forEventClass: AEEventClass(kCoreEventClass),
			andEventID: AEEventID(kAEQuitApplication)
		)
	}

	@objc private func handleQuitEvent(
		_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor
	) {
		requestQuit()
	}

	@objc private func requestQuit() {
		switch blockingPresentationForQuit?() {
		case .none:
			NSApp.terminate(nil)
		case .settings:
			dismissSettingsForQuit?()
			terminateOnceSheetDetaches()
		case .update, .failure, .popup:
			break
		}
	}

	private func terminateOnceSheetDetaches(attempt: Int = 0) {
		guard NSApp.windows.contains(where: { $0.attachedSheet != nil }),
			attempt < AppConstants.Timeouts.quitSheetDetachPollLimit
		else {
			NSApp.terminate(nil)
			return
		}
		// SwiftUI clears presentation state before AppKit detaches the sheet.
		let timer = Timer(
			timeInterval: AppConstants.Timeouts.quitSheetDetachPollInterval,
			repeats: false
		) { [weak self] _ in
			MainActor.assumeIsolated { self?.terminateOnceSheetDetaches(attempt: attempt + 1) }
		}
		RunLoop.main.add(timer, forMode: .common)
	}

	// requestQuit() applies presentation policy before asking AppKit to terminate.
	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		.terminateNow
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
					registerQuitPresentationQuery: {
						appDelegate.blockingPresentationForQuit = $0
					},
					registerQuitDismissal: { appDelegate.dismissSettingsForQuit = $0 }
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
