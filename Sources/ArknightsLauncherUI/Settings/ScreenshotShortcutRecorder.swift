// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsInfrastructure
import Carbon.HIToolbox
import SwiftUI

/// Captures the next key combination for the screenshot shortcut. Escape cancels.
struct ScreenshotShortcutRecorder: View {
	let onRecord: (ScreenshotShortcut) -> Void
	let onCancel: () -> Void
	@Environment(\.launcherTheme) private var theme
	/// Removed on every exit path: a recorded key, Cancel, Escape, or leaving the screen.
	@State private var monitor: Any?

	var body: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Text("Press a shortcut…")
				.foregroundStyle(theme.textSecondary)
			CapsuleActionButton(title: "Cancel", tone: .neutral, action: cancel)
		}
		.onAppear {
			monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
				handle(event)
				return nil
			}
		}
		.onDisappear(perform: removeMonitor)
	}

	/// Consumes every key press. A combination that cannot be used keeps the recorder open.
	private func handle(_ event: NSEvent) {
		if Int(event.keyCode) == kVK_Escape {
			cancel()
		} else if let shortcut = Self.shortcut(for: event) {
			removeMonitor()
			onRecord(shortcut)
		}
	}

	private func cancel() {
		removeMonitor()
		onCancel()
	}

	private func removeMonitor() {
		if let monitor { NSEvent.removeMonitor(monitor) }
		monitor = nil
	}

	private static let functionKeyCodes = [
		kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
		kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
	]

	private static let namedKeys: [Int: String] = [
		kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
		kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
	]

	/// Accepts a combination with Control, Option, or Command, or an F1 to F20 key on its own.
	private static func shortcut(for event: NSEvent) -> ScreenshotShortcut? {
		let keyCode = Int(event.keyCode)
		let modifiers = combinationModifiers(for: event.modifierFlags)
		let hasShortcutModifier = !modifiers.isDisjoint(with: [.control, .option, .command])
		let isBareFunctionKey = modifiers.isEmpty && functionKeyCodes.contains(keyCode)
		guard hasShortcutModifier || isBareFunctionKey, let label = keyLabel(for: event) else {
			return nil
		}
		return .custom(
			HotKeyCombination(keyCode: UInt32(keyCode), modifiers: modifiers), label: label)
	}

	private static func keyLabel(for event: NSEvent) -> String? {
		let keyCode = Int(event.keyCode)
		if let index = functionKeyCodes.firstIndex(of: keyCode) { return "F\(index + 1)" }
		if let name = namedKeys[keyCode] { return name }
		guard let characters = event.charactersIgnoringModifiers?.uppercased(), !characters.isEmpty,
			characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
		else { return nil }
		return characters
	}

	private static func combinationModifiers(
		for flags: NSEvent.ModifierFlags
	) -> HotKeyCombination.Modifiers {
		var modifiers: HotKeyCombination.Modifiers = []
		if flags.contains(.control) { modifiers.insert(.control) }
		if flags.contains(.option) { modifiers.insert(.option) }
		if flags.contains(.shift) { modifiers.insert(.shift) }
		if flags.contains(.command) { modifiers.insert(.command) }
		return modifiers
	}
}
