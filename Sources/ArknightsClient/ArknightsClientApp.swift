// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsAudio
import ArknightsCore
import ArknightsLauncherUI
import ArknightsOnboarding
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	weak var model: LauncherViewModel? {
		didSet { launchPendingRegion() }
	}
	/// A launch requested from a notification before the scene created the model (cold start).
	private var pendingLaunchRegion: GameRegion?
	weak var launcherUpdater: LauncherUpdaterController?
	var terminateApplication: () -> Void = { NSApp.terminate(nil) }
	var stopGame: (() -> Void)?
	var openSettings: (() -> Void)?
	var blockingPresentationForQuit: (() -> LauncherPresentationDestination?)?
	var dismissPresentationForQuit: (() -> Void)?
	private var quitSheetObserver: Any?
	private var quitSheetDetachTask: Task<Void, Never>?

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
		installNotificationDelegate()
	}

	// `UNUserNotificationCenter.current()` traps outside an app bundle, as in `swift run`.
	private func installNotificationDelegate() {
		guard Bundle.main.bundleURL.pathExtension == "app" else { return }
		UNUserNotificationCenter.current().delegate = self
	}

	// A key SwiftUI sheet can prevent the default nil target from reaching NSApp.
	private func fixQuitMenuItemTarget() {
		guard
			let item = NSApp.mainMenu?.items.lazy.compactMap({ $0.submenu }).flatMap(\.items)
				.first(where: { $0.action == #selector(NSApplication.terminate(_:)) })
		else { return }
		item.target = self
		item.action = #selector(requestQuitFromMenu)
	}

	// A key sheet can also bypass the menu item's Command-Q dispatch.
	private func installQuitKeyMonitor() {
		_ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
				event.charactersIgnoringModifiers?.lowercased() == "q"
			else { return event }
			self?.requestQuitFromMenu()
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
		_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor
	) {
		// Logout, restart, and shutdown attach a quit reason; the launcher never vetoes them.
		let isSystemInitiated =
			event.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
		requestQuit(isSystemInitiated: isSystemInitiated)
	}

	@objc private func requestQuitFromMenu() {
		requestQuit(isSystemInitiated: false)
	}

	/// A button in a modal notice, which must close the sheet before AppKit accepts quitting.
	func requestQuitFromApplication() {
		requestQuit(isSystemInitiated: false)
	}

	private func requestQuit(isSystemInitiated: Bool) {
		if !isSystemInitiated, let installationID = launcherUpdater?.installationID {
			guard launcherUpdater?.canTerminateForUpdate == true else { return }
			dismissPresentationForQuit?()
			terminateOnceSheetDetaches(installationID: installationID)
			return
		}
		switch blockingPresentationForQuit?() {
		case .none:
			terminateApplication()
		case .update where !isSystemInitiated:
			// Sparkle owns this prompt and may send its own quit requests while it is visible.
			break
		case .settings, .failure, .popup, .update:
			dismissPresentationForQuit?()
			terminateOnceSheetDetaches()
		}
	}

	private func terminateOnceSheetDetaches(installationID: UUID? = nil) {
		if let installationID {
			guard launcherUpdater?.installationID == installationID,
				launcherUpdater?.canTerminateForUpdate == true
			else { return }
		}
		guard NSApp.windows.contains(where: { $0.attachedSheet != nil }) else {
			terminateApplication()
			return
		}
		// SwiftUI clears presentation state before AppKit detaches the sheet, so wait for
		// the sheet-end event. The one-shot timeout covers the event never arriving.
		guard quitSheetObserver == nil else { return }
		quitSheetObserver = NotificationCenter.default.addObserver(
			forName: NSWindow.didEndSheetNotification, object: nil, queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				self?.sheetDidEnd(installationID: installationID)
			}
		}
		quitSheetDetachTask = Task { [weak self] in
			do {
				try await Task.sleep(for: AppConstants.Timeouts.quitSheetDetachTimeout)
			} catch {
				return
			}
			self?.quitAfterSheetTimeout(installationID: installationID)
		}
	}

	private func sheetDidEnd(installationID: UUID?) {
		guard !NSApp.windows.contains(where: { $0.attachedSheet != nil }) else { return }
		terminateOnce(installationID: installationID)
	}

	private func quitAfterSheetTimeout(installationID: UUID?) {
		// The bounded fallback proceeds even when a sheet is still attached.
		terminateOnce(installationID: installationID)
	}

	// The observer doubles as the arming token: the first path to reach this removes it,
	// so the other path can no longer terminate twice.
	private func terminateOnce(installationID: UUID?) {
		guard let observer = quitSheetObserver else { return }
		NotificationCenter.default.removeObserver(observer)
		quitSheetObserver = nil
		quitSheetDetachTask?.cancel()
		quitSheetDetachTask = nil
		if let installationID {
			guard launcherUpdater?.installationID == installationID,
				launcherUpdater?.canTerminateForUpdate == true
			else { return }
		}
		terminateApplication()
	}

	// requestQuit(isSystemInitiated:) applies presentation policy before asking AppKit to terminate.
	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		.terminateNow
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		true
	}

	func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		let menu = NSMenu()
		menu.autoenablesItems = false
		if let model {
			let installedRegions = model.installation.installedRegions
			for region in installedRegions {
				let item = NSMenuItem(
					title: "Play \(region.displayName)",
					action: #selector(playRegion(_:)),
					keyEquivalent: ""
				)
				item.target = self
				item.representedObject = region.rawValue
				item.isEnabled = model.actions.canRequestDockLaunch
				menu.addItem(item)
			}
			if !installedRegions.isEmpty {
				menu.addItem(.separator())
			}
		}

		let screenshotItem = NSMenuItem(
			title: "Take Screenshot",
			action: #selector(takeScreenshot),
			keyEquivalent: ""
		)
		screenshotItem.target = self
		screenshotItem.isEnabled = model?.screenshots.canTakeScreenshot == true
		menu.addItem(screenshotItem)
		menu.addItem(.separator())

		let settingsItem = NSMenuItem(
			title: "Settings…",
			action: #selector(showSettings),
			keyEquivalent: ","
		)
		settingsItem.keyEquivalentModifierMask = [.command]
		settingsItem.target = self
		settingsItem.isEnabled = openSettings != nil
		menu.addItem(settingsItem)
		let reportItem = NSMenuItem(
			title: "Report a Problem…",
			action: #selector(reportProblem),
			keyEquivalent: ""
		)
		reportItem.target = self
		menu.addItem(reportItem)
		return menu
	}

	@objc private func playRegion(_ sender: NSMenuItem) {
		guard
			let rawValue = sender.representedObject as? String,
			let region = GameRegion(rawValue: rawValue)
		else {
			showMainWindow()
			return
		}
		launch(region)
	}

	/// Launches through the Dock guards and shows the window when the launch is refused.
	private func launch(_ region: GameRegion) {
		guard let model else {
			pendingLaunchRegion = region
			showMainWindow()
			return
		}
		Task {
			if !(await model.actions.launchFromDock(region: region)) {
				showMainWindow()
			}
		}
	}

	private func launchPendingRegion() {
		guard model != nil, let region = pendingLaunchRegion else { return }
		pendingLaunchRegion = nil
		launch(region)
	}

	@objc private func takeScreenshot() {
		model?.screenshots.takeScreenshot()
	}

	@objc private func reportProblem() {
		model?.openProblemReport(source: .dock)
	}

	@objc private func showSettings() {
		showMainWindow()
		openSettings?()
	}

	fileprivate func showMainWindow() {
		NSApp.activate(ignoringOtherApps: true)
		let window =
			NSApp.mainWindow ?? NSApp.keyWindow
			?? NSApp.windows.first(where: \.canBecomeMain)
		window?.deminiaturize(nil)
		window?.makeKeyAndOrderFront(nil)
	}
}

extension AppDelegate: UNUserNotificationCenterDelegate {
	// The system calls these off the main actor.
	nonisolated func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification
	) async -> UNNotificationPresentationOptions {
		// The launcher is the foreground app when its reminder is due, so show it as a banner.
		[.banner, .sound]
	}

	nonisolated func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		didReceive response: UNNotificationResponse
	) async {
		let content = response.notification.request.content
		if content.categoryIdentifier == AppConstants.Screenshots.notificationCategory {
			// A tap or the Show in Finder button both reveal the file. Neither needs the launcher.
			if let path = content.userInfo[AppConstants.Screenshots.pathUserInfoKey] as? String {
				await MainActor.run {
					NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
				}
			}
			return
		}
		let reminderRegion =
			content.categoryIdentifier == AppConstants.Reminders.notificationCategory
			? (content.userInfo[AppConstants.Reminders.regionUserInfoKey] as? String)
				.flatMap(GameRegion.init(rawValue:))
			: nil
		await MainActor.run {
			if let reminderRegion {
				launch(reminderRegion)
			} else {
				showMainWindow()
			}
		}
	}
}

@main
struct ArknightsClientApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@State private var model: LauncherViewModel
	@State private var musicController: BackgroundMusicController
	@State private var onboarding: OnboardingCoordinator

	init() {
		StartupTimeline.shared.mark("app entry")
		let model = LauncherViewModel.makeDefault()
		StartupTimeline.shared.mark("composition done")
		_model = State(wrappedValue: model)
		#if DEBUG
			let initialMusicTitle = model.developerAccessibilityMusicTitle
		#else
			let initialMusicTitle: String? = nil
		#endif
		_musicController = State(
			wrappedValue: BackgroundMusicController(
				lifecycle: model.lifecycle,
				settings: model.settings,
				launcherIconManager: model.launcherIconManager,
				initialMusicTitle: initialMusicTitle,
				openURL: { _ = NSWorkspace.shared.open($0) }
			)
		)
		_onboarding = State(
			wrappedValue: OnboardingCoordinator(
				store: OnboardingProgressStore(defaults: model.preferences.defaults)
			)
		)
	}

	var body: some Scene {
		WindowGroup("Arknights Client") {
			ContentView(
				model: model,
				musicController: musicController,
				onboarding: onboarding,
				registerOpenSettings: { appDelegate.openSettings = $0 },
				registerQuitPresentationQuery: {
					appDelegate.blockingPresentationForQuit = $0
				},
				registerQuitDismissal: { appDelegate.dismissPresentationForQuit = $0 }
			)
			.frame(minWidth: 880, minHeight: 560)
			.onChange(of: model.settings.launcherAppearance, initial: true) { _, appearance in
				NSApp.appearance = appearance.nsAppearance
			}
			.onAppear { [appDelegate] in
				appDelegate.model = model
				appDelegate.launcherUpdater = model.communication.launcherUpdater
				appDelegate.stopGame = { model.actions.stopGameForApplicationTermination() }
				model.requestApplicationQuit = { [weak appDelegate] in
					appDelegate?.requestQuitFromApplication()
				}
				NSApp.activate(ignoringOtherApps: true)
			}
		}
		.windowStyle(.hiddenTitleBar)
		.defaultSize(width: 1040, height: 680)
		.windowResizability(.contentMinSize)
		.commands {
			CommandMenu("Game") {
				Button("Take Screenshot") {
					model.screenshots.takeScreenshot()
				}
				.disabled(!model.screenshots.canTakeScreenshot)
			}
			CommandGroup(replacing: .help) {
				Button("Report a Problem…") {
					model.openProblemReport(source: .helpMenu)
				}
				Button("Save Diagnostics…") {
					Task { await model.actions.saveDiagnostics() }
				}
				.disabled(model.actions.isSavingDiagnostics)
				Divider()
				Button("Troubleshooting Guide") {
					NSWorkspace.shared.open(SupportLinks.troubleshootingGuide)
				}
				Button("Contact Publisher Support…") {
					NSWorkspace.shared.open(
						SupportLinks.contact(for: model.installation.region))
				}
			}
		}
		Window("Measure Game Window", id: GameWindowMeasureView.sceneID) {
			GameWindowMeasureView(model: model)
		}
		.defaultLaunchBehavior(.suppressed)
		.restorationBehavior(.disabled)
	}
}
