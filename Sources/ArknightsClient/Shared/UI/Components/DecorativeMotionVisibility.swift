// SPDX-License-Identifier: MPL-2.0

import AppKit
import Observation
import SwiftUI

/// Controls work that only exists to make a visible launcher feel alive.
@MainActor
@Observable
final class DecorativeMotionVisibility {
	private let notificationCenter: NotificationCenter
	private weak var window: NSWindow?
	private var observers: [NSObjectProtocol] = []

	private(set) var isEnabled = true

	init(notificationCenter: NotificationCenter = .default) {
		self.notificationCenter = notificationCenter
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
		refreshWindowState()
	}

	func detach() {
		for observer in observers {
			notificationCenter.removeObserver(observer)
		}
		observers.removeAll(keepingCapacity: false)
		window = nil
		isEnabled = true
	}

	func update(
		applicationIsActive: Bool,
		applicationIsHidden: Bool,
		windowIsVisible: Bool,
		windowIsMiniaturized: Bool,
		windowIsOccluded: Bool
	) {
		isEnabled = DecorativeMotionVisibilityPolicy.isEnabled(
			applicationIsActive: applicationIsActive,
			applicationIsHidden: applicationIsHidden,
			windowIsVisible: windowIsVisible,
			windowIsMiniaturized: windowIsMiniaturized,
			windowIsOccluded: windowIsOccluded
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
		guard let window else {
			update(
				applicationIsActive: true,
				applicationIsHidden: false,
				windowIsVisible: true,
				windowIsMiniaturized: false,
				windowIsOccluded: false
			)
			return
		}
		update(
			applicationIsActive: NSApp.isActive,
			applicationIsHidden: NSApp.isHidden,
			windowIsVisible: window.isVisible,
			windowIsMiniaturized: window.isMiniaturized,
			windowIsOccluded: !window.occlusionState.contains(.visible)
		)
	}
}

enum DecorativeMotionVisibilityPolicy {
	static func isEnabled(
		applicationIsActive: Bool,
		applicationIsHidden: Bool,
		windowIsVisible: Bool,
		windowIsMiniaturized: Bool,
		windowIsOccluded: Bool
	) -> Bool {
		applicationIsActive && !applicationIsHidden && windowIsVisible && !windowIsMiniaturized
			&& !windowIsOccluded
	}
}

struct DecorativeMotionClock {
	private(set) var pausedPhase = 0.0
	private var startDate: Date?

	mutating func begin(at date: Date, cycleDuration: TimeInterval) {
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
struct WindowVisibilityReader: NSViewRepresentable {
	let visibility: DecorativeMotionVisibility

	func makeNSView(context: Context) -> WindowVisibilityTrackingView {
		WindowVisibilityTrackingView(visibility: visibility)
	}

	func updateNSView(_ nsView: WindowVisibilityTrackingView, context: Context) {
		nsView.visibility = visibility
		nsView.attachIfNeeded()
	}
}

@MainActor
final class WindowVisibilityTrackingView: NSView {
	var visibility: DecorativeMotionVisibility
	private weak var observedWindow: NSWindow?

	init(visibility: DecorativeMotionVisibility) {
		self.visibility = visibility
		super.init(frame: .zero)
		isHidden = true
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		attachIfNeeded()
	}

	override func removeFromSuperview() {
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
	var decorativeMotionEnabled: Bool {
		get { self[DecorativeMotionEnabledKey.self] }
		set { self[DecorativeMotionEnabledKey.self] = newValue }
	}
}
