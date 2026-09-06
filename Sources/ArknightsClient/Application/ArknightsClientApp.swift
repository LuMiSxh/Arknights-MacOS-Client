// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	weak var model: LauncherViewModel?
	var stopGame: (() -> Void)?
	var openSettings: (() -> Void)?
	var currentBlockingPresentation: (() -> LauncherPresentationDestination?)?
	var dismissForQuit: (() -> Void)?
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

	// The Quit item's default target and action call `-[NSApplication terminate:]` directly,
	// as does Command-Q's key equivalent and the Dock icon's own Quit item (via the Apple
	// Event handler below). All three turned out to be unreliable while Settings is open,
	// each for a different reason: `-terminate:` always asks `NSApp.delegate` whether to
	// proceed, but `@NSApplicationDelegateAdaptor` installs a SwiftUI-owned proxy object as
	// that delegate — not this class directly — and while any SwiftUI `.sheet` is presented,
	// that proxy answers the question itself instead of forwarding it to
	// applicationShouldTerminate(_:) below, silently refusing to quit regardless of what this
	// class would have said. So every quit path is retargeted at requestQuit() instead, which
	// makes its own decision before ever calling `-terminate:`, rather than relying on being
	// consulted once that call is already underway.
	private func fixQuitMenuItemTarget() {
		guard
			let item = NSApp.mainMenu?.items.lazy.compactMap({ $0.submenu }).flatMap(\.items)
				.first(where: { $0.action == #selector(NSApplication.terminate(_:)) })
		else { return }
		item.target = self
		item.action = #selector(requestQuit)
	}

	// A local event monitor sees every key event for this app regardless of which window (or
	// sheet) is key, unlike the menu item's key-equivalent dispatch above — Command-Q reaching
	// requestQuit() at all while Settings is key depends on this, not on the menu item.
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

	// AppKit's own handler for the standard Quit Apple Event — what the Dock icon's own Quit
	// item and any external `tell application ... to quit` actually send — refuses the
	// request outright with a user-canceled error while a sheet is attached to the key
	// window, without ever calling applicationShouldTerminate(_:) at all. Installing our own
	// handler for the same event routes it through requestQuit() like every other path,
	// bypassing that built-in refusal.
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

	// The single point every quit path (the menu item, Command-Q, and the Apple Event handler
	// above) funnels through. The update/failure/popup presentations share one sheet slot with
	// Settings but carry information (an in-progress update, an error, an announcement) that
	// shouldn't be discarded just to unblock quitting; Settings and everything reachable from
	// it (a bundled document, the preset gallery) have no such state, so quitting through those
	// is fine — but only once dismissForQuit() has actually taken effect on screen. Calling
	// dismissForQuit() updates the SwiftUI @State immediately, but the AppKit sheet window it's
	// bound to only actually detaches on the next render pass (closing with its usual short
	// animation), and the SwiftUI-owned delegate proxy's refusal is tied to that real detachment,
	// not the @State value — so this polls NSWindow.attachedSheet itself rather than the query,
	// which would report "nothing presented" a beat before termination can actually proceed.
	@objc private func requestQuit() {
		switch currentBlockingPresentation?() {
		case .none:
			NSApp.terminate(nil)
		case .settings:
			dismissForQuit?()
			terminateOnceSheetDetaches()
		case .update, .failure, .popup:
			break
		}
	}

	private func terminateOnceSheetDetaches(attempt: Int = 0) {
		guard NSApp.windows.contains(where: { $0.attachedSheet != nil }), attempt < 20 else {
			NSApp.terminate(nil)
			return
		}
		let timer = Timer(timeInterval: 0.05, repeats: false) { [weak self] _ in
			MainActor.assumeIsolated { self?.terminateOnceSheetDetaches(attempt: attempt + 1) }
		}
		RunLoop.main.add(timer, forMode: .common)
	}

	// requestQuit() only ever calls `-terminate:` once it has already decided quitting is safe,
	// but `-terminate:` still asks the SwiftUI-owned delegate proxy that question again —
	// without an answer from this class, its own default may not agree, even with nothing
	// presented. Always confirming here is what actually lets termination complete once
	// requestQuit()'s own check has already passed.
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
					registerQuitDismissalQuery: { appDelegate.currentBlockingPresentation = $0 },
					registerQuitDismissal: { appDelegate.dismissForQuit = $0 }
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
