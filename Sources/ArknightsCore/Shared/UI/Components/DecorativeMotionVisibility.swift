// SPDX-License-Identifier: MPL-2.0

import AppKit
import Observation
import SwiftUI

/// Controls work that only exists to make a visible launcher feel alive.
@MainActor
@Observable
package final class DecorativeMotionVisibility {
	private let notificationCenter: NotificationCenter
	private weak var window: NSWindow?
	private var observers: [NSObjectProtocol] = []

	package private(set) var isEnabled = true
	package private(set) var isGameActive = false
	private(set) var isLowPowerModeEnabled: Bool
	private let lowPowerModeProvider: @MainActor () -> Bool

	package init(
		notificationCenter: NotificationCenter = .default,
		lowPowerModeProvider: @escaping @MainActor () -> Bool = {
			ProcessInfo.processInfo.isLowPowerModeEnabled
		}
	) {
		self.notificationCenter = notificationCenter
		self.lowPowerModeProvider = lowPowerModeProvider
		isLowPowerModeEnabled = lowPowerModeProvider()
	}

	isolated deinit {
		for observer in observers {
			notificationCenter.removeObserver(observer)
		}
	}

	var isObserving: Bool { !observers.isEmpty }

	func attach(to window: NSWindow) {
		guard self.window !== window else {
			refreshWindowState()
			return
		}

		detach()
		self.window = window
		observe(NSApplication.didBecomeActiveNotification)
		observe(NSApplication.didResignActiveNotification)
		observe(NSApplication.didHideNotification)
		observe(NSApplication.didUnhideNotification)
		observe(NSWindow.didBecomeKeyNotification, object: window)
		observe(NSWindow.didResignKeyNotification, object: window)
		observe(NSWindow.didBecomeMainNotification, object: window)
		observe(NSWindow.didResignMainNotification, object: window)
		observe(NSWindow.didMiniaturizeNotification, object: window)
		observe(NSWindow.didDeminiaturizeNotification, object: window)
		observe(NSWindow.didChangeOcclusionStateNotification, object: window)
		observe(.NSProcessInfoPowerStateDidChange)
		refreshWindowState()
	}

	func detach() {
		for observer in observers {
			notificationCenter.removeObserver(observer)
		}
		observers.removeAll(keepingCapacity: false)
		window = nil
		refreshWindowState()
	}

	/// Applies to every decorative loop, including those inside sheets.
	package func setGameActive(_ isActive: Bool) {
		isGameActive = isActive
		refreshWindowState()
	}

	package func update(
		applicationIsActive: Bool,
		applicationIsHidden: Bool,
		windowIsVisible: Bool,
		windowIsMiniaturized: Bool,
		windowIsOccluded: Bool,
		isGameActive: Bool? = nil,
		isLowPowerModeEnabled: Bool? = nil
	) {
		self.isGameActive = isGameActive ?? self.isGameActive
		self.isLowPowerModeEnabled = isLowPowerModeEnabled ?? self.isLowPowerModeEnabled
		isEnabled = DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: applicationIsActive,
			applicationIsHidden: applicationIsHidden,
			windowIsVisible: windowIsVisible,
			windowIsMiniaturized: windowIsMiniaturized,
			windowIsOccluded: windowIsOccluded,
			isGameActive: self.isGameActive,
			isLowPowerModeEnabled: self.isLowPowerModeEnabled
		)
	}

	private func observe(_ name: Notification.Name, object: Any? = nil) {
		let observer = notificationCenter.addObserver(
			forName: name,
			object: object,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				self?.refreshWindowState()
			}
		}
		observers.append(observer)
	}

	private func refreshWindowState() {
		let lowPower = lowPowerModeProvider()
		guard let window else {
			update(
				applicationIsActive: true,
				applicationIsHidden: false,
				windowIsVisible: true,
				windowIsMiniaturized: false,
				windowIsOccluded: false,
				isLowPowerModeEnabled: lowPower
			)
			return
		}
		update(
			applicationIsActive: NSApp.isActive,
			applicationIsHidden: NSApp.isHidden,
			windowIsVisible: window.isVisible,
			windowIsMiniaturized: window.isMiniaturized,
			windowIsOccluded: !window.occlusionState.contains(.visible),
			isLowPowerModeEnabled: lowPower
		)
	}
}

package enum DecorativeMotionVisibilityPolicy {
	package static func isEnabled(
		applicationIsActive: Bool,
		applicationIsHidden: Bool,
		windowIsVisible: Bool,
		windowIsMiniaturized: Bool,
		windowIsOccluded: Bool,
		isGameActive: Bool = false,
		isLowPowerModeEnabled: Bool = false
	) -> Bool {
		applicationIsActive && !applicationIsHidden && windowIsVisible && !windowIsMiniaturized
			&& !windowIsOccluded && !isGameActive && !isLowPowerModeEnabled
	}

	/// The covered gate applies to the home layer only; sheets keep animating.
	package static func homeLayerEnabled(base: Bool, isCovered: Bool) -> Bool {
		base && !isCovered
	}
}

struct DecorativeMotionClock {
	private(set) var pausedPhase = 0.0
	private var startDate: Date?

	package mutating func begin(at date: Date, cycleDuration: TimeInterval) {
		guard startDate == nil else { return }
		startDate = date.addingTimeInterval(-pausedPhase * cycleDuration)
	}

	mutating func pause(at date: Date, cycleDuration: TimeInterval) {
		pausedPhase = phase(at: date, cycleDuration: cycleDuration)
		startDate = nil
	}

	mutating func resume(at date: Date, cycleDuration: TimeInterval) {
		begin(at: date, cycleDuration: cycleDuration)
	}

	func phase(at date: Date, cycleDuration: TimeInterval) -> Double {
		guard let startDate, cycleDuration > 0 else { return pausedPhase }
		let elapsed = max(0, date.timeIntervalSince(startDate))
		return (elapsed.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration
	}
}

@MainActor
package struct WindowVisibilityReader: NSViewRepresentable {
	let visibility: DecorativeMotionVisibility

	package init(visibility: DecorativeMotionVisibility) {
		self.visibility = visibility
	}

	package func makeNSView(context: Context) -> WindowVisibilityTrackingView {
		WindowVisibilityTrackingView(visibility: visibility)
	}

	package func updateNSView(_ nsView: WindowVisibilityTrackingView, context: Context) {
		nsView.visibility = visibility
		nsView.attachIfNeeded()
	}
}

@MainActor
package final class WindowVisibilityTrackingView: NSView {
	var visibility: DecorativeMotionVisibility
	private weak var observedWindow: NSWindow?

	package init(visibility: DecorativeMotionVisibility) {
		self.visibility = visibility
		super.init(frame: .zero)
		isHidden = true
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	package override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		attachIfNeeded()
	}

	package override func removeFromSuperview() {
		visibility.detach()
		observedWindow = nil
		super.removeFromSuperview()
	}

	func attachIfNeeded() {
		guard let window else {
			visibility.detach()
			observedWindow = nil
			return
		}
		guard observedWindow !== window else { return }
		observedWindow = window
		visibility.attach(to: window)
	}
}

private struct DecorativeMotionEnabledKey: EnvironmentKey {
	static let defaultValue = true
}

extension EnvironmentValues {
	package var decorativeMotionEnabled: Bool {
		get { self[DecorativeMotionEnabledKey.self] }
		set { self[DecorativeMotionEnabledKey.self] = newValue }
	}
}
