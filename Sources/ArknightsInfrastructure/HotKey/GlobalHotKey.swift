// SPDX-License-Identifier: MPL-2.0

import Carbon.HIToolbox
import Foundation
import Synchronization

/// A key and its modifiers, in the terms Carbon's hot key API uses.
package struct HotKeyCombination: Hashable, Sendable {
	package struct Modifiers: OptionSet, Hashable, Sendable {
		package let rawValue: UInt32
		package init(rawValue: UInt32) { self.rawValue = rawValue }

		package static let control = Modifiers(rawValue: UInt32(controlKey))
		package static let option = Modifiers(rawValue: UInt32(optionKey))
		package static let command = Modifiers(rawValue: UInt32(cmdKey))
		package static let shift = Modifiers(rawValue: UInt32(shiftKey))
	}

	package static let keyCodeS = UInt32(kVK_ANSI_S)
	package static let keyCodeF13 = UInt32(kVK_F13)

	package let keyCode: UInt32
	package let modifiers: Modifiers

	package init(keyCode: UInt32, modifiers: Modifiers = []) {
		self.keyCode = keyCode
		self.modifiers = modifiers
	}
}

/// A system-wide keyboard shortcut that works while another app is frontmost.
///
/// Carbon's `RegisterEventHotKey` consumes the key press, so the frontmost app never sees it, and
/// it needs no Accessibility or Input Monitoring permission. The shortcut stays registered until
/// `cancel()` or deinit.
package final class GlobalHotKey: Sendable {
	private struct Registration {
		let hotKey: EventHotKeyRef
		let eventHandler: EventHandlerRef
		let box: Unmanaged<HotKeyBox>
	}

	fileprivate static let signature: OSType = 0x4152_4B48  // "ARKH"
	private static let nextID = Mutex<UInt32>(1)

	private let registration: Mutex<Registration?>

	/// Registers the shortcut. Returns nil when another app already owns the combination.
	///
	/// Carbon delivers the press on the main thread. `handler` runs there and must hop to its
	/// own actor.
	package init?(_ combination: HotKeyCombination, handler: @escaping @Sendable () -> Void) {
		let id = Self.nextID.withLock { value -> UInt32 in
			defer { value += 1 }
			return value
		}
		let box = Unmanaged.passRetained(HotKeyBox(id: id, handler: handler))
		var eventType = EventTypeSpec(
			eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
		var eventHandler: EventHandlerRef?
		guard
			InstallEventHandler(
				GetApplicationEventTarget(), hotKeyPressed, 1, &eventType, box.toOpaque(),
				&eventHandler) == noErr,
			let eventHandler
		else {
			box.release()
			return nil
		}
		var hotKey: EventHotKeyRef?
		guard
			RegisterEventHotKey(
				combination.keyCode, combination.modifiers.rawValue,
				EventHotKeyID(signature: Self.signature, id: id), GetApplicationEventTarget(), 0,
				&hotKey) == noErr,
			let hotKey
		else {
			RemoveEventHandler(eventHandler)
			box.release()
			return nil
		}
		registration = Mutex(Registration(hotKey: hotKey, eventHandler: eventHandler, box: box))
	}

	/// Releases the shortcut. Calling it again does nothing.
	package func cancel() {
		guard let current = registration.withLock({ value -> Registration? in value.take() })
		else { return }
		UnregisterEventHotKey(current.hotKey)
		RemoveEventHandler(current.eventHandler)
		current.box.release()
	}

	deinit { cancel() }
}

private final class HotKeyBox: Sendable {
	let id: UInt32
	let handler: @Sendable () -> Void
	init(id: UInt32, handler: @escaping @Sendable () -> Void) {
		self.id = id
		self.handler = handler
	}
}

// Every registered hot key adds a handler to the application target, so each handler sees every
// press and answers only its own ID.
private func hotKeyPressed(
	_ call: EventHandlerCallRef?,
	_ event: EventRef?,
	_ userData: UnsafeMutableRawPointer?
) -> OSStatus {
	guard let event, let userData else { return OSStatus(eventNotHandledErr) }
	var pressed = EventHotKeyID()
	let status = GetEventParameter(
		event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
		MemoryLayout<EventHotKeyID>.size, nil, &pressed)
	let box = Unmanaged<HotKeyBox>.fromOpaque(userData).takeUnretainedValue()
	guard
		status == noErr, pressed.signature == GlobalHotKey.signature, pressed.id == box.id
	else { return OSStatus(eventNotHandledErr) }
	box.handler()
	return noErr
}
