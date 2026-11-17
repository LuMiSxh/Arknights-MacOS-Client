// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct DiscordIPCConnectionTests {
	@Test
	func handshakeTimeoutFiresThroughTheInjectedClock() async throws {
		let pair = try ConnectedSocketPair()
		defer { pair.closePeer() }
		let clock = RecordingClock()
		let descriptor = pair.clientDescriptor
		let connection = DiscordIPCConnection(
			maximumPayloadBytes: 4_096,
			handshakeTimeout: .seconds(30),
			clock: clock,
			openSocket: { descriptor }
		)

		await expectConnectError(connection) { error in
			guard case .handshakeTimedOut = error else { return false }
			return true
		}
		#expect(clock.sleeps.count == 1)
	}

	@Test
	func readyCompletesTheHandshake() async throws {
		let pair = try ConnectedSocketPair()
		defer { pair.closePeer() }
		let connection = Self.connection(on: pair)
		try pair.send(.frame, json: #"{"evt":"READY"}"#)

		try await connection.connect(clientID: Self.clientID)
		await connection.disconnect()
	}

	@Test
	func errorDuringTheHandshakeFailsConnectWithTheDiscordError() async throws {
		let pair = try ConnectedSocketPair()
		defer { pair.closePeer() }
		let connection = Self.connection(on: pair)
		try pair.send(.frame, json: #"{"evt":"ERROR","data":{"code":4000,"message":"bad id"}}"#)

		await expectConnectError(connection) { error in
			guard case .discordError(let code, let message) = error else { return false }
			return code == 4000 && message == "bad id"
		}
	}

	@Test
	func peerEndOfFileResumesDisconnectWaiters() async throws {
		let pair = try ConnectedSocketPair()
		try pair.send(.frame, json: #"{"evt":"READY"}"#)
		let connection = Self.connection(on: pair)
		try await connection.connect(clientID: Self.clientID)

		async let first: Void = connection.waitForDisconnect()
		async let second: Void = connection.waitForDisconnect()
		pair.closePeer()
		_ = await (first, second)
		await connection.waitForDisconnect()
	}

	@Test(arguments: [
		"[1, 2]",

		#"{"evt":5}"#,
		#"{"evt":"ERROR","data":[1]}"#,
		#"{"evt":"ERROR","data":{"code":"x","message":3}}"#,
	])
	func unexpectedPayloadShapesKeepTheConnectionOpen(payload: String) async throws {
		let pair = try ConnectedSocketPair()
		defer { pair.closePeer() }
		try pair.send(.frame, json: #"{"evt":"READY"}"#)
		let connection = Self.connection(on: pair)
		try await connection.connect(clientID: Self.clientID)

		try pair.send(.frame, json: payload)
		try pair.send(.ping, json: "{}")

		// A pong after the odd payload shows the connection processed it and stayed open.
		#expect(try pair.readFrame(opcode: .pong) != nil)
		await connection.disconnect()
	}

	@Test
	func cancellingTheConnectingTaskThrowsCancellationError() async throws {
		let pair = try ConnectedSocketPair()
		defer { pair.closePeer() }
		let connection = Self.connection(on: pair, clock: SuspendedClock())
		let attempt = Task { try await connection.connect(clientID: Self.clientID) }

		// The peer sees the handshake once the connection waits for READY.
		#expect(try pair.readFrame(opcode: .handshake) != nil)
		attempt.cancel()

		do {
			try await attempt.value
			Issue.record("connect returned without a READY dispatch.")
		} catch is CancellationError {
		}
		await connection.waitForDisconnect()
	}

	private static func connection(
		on pair: ConnectedSocketPair,
		clock: any Clock<Duration> = SuspendedClock()
	) -> DiscordIPCConnection {
		let descriptor = pair.clientDescriptor
		return DiscordIPCConnection(
			maximumPayloadBytes: 4_096,
			handshakeTimeout: .seconds(30),
			clock: clock,
			openSocket: { descriptor }
		)
	}

	private func expectConnectError(
		_ connection: DiscordIPCConnection,
		matching matches: (DiscordIPCError) -> Bool
	) async {
		do {
			try await connection.connect(clientID: Self.clientID)
			Issue.record("connect returned without a READY dispatch.")
		} catch let error as DiscordIPCError {
			#expect(matches(error), "Unexpected error \(error).")
		} catch {
			Issue.record("Unexpected error \(error).")
		}
	}

	private static let clientID = "1539589207381770261"
}

private enum SocketPairError: Error {
	case posix(Int32)
}

/// Two connected AF_UNIX descriptors. The connection end is non-blocking, as a real socket is.
private final class ConnectedSocketPair {
	let clientDescriptor: Int32
	let peerDescriptor: Int32
	private var received = Data()

	init() throws {
		var descriptors: [Int32] = [-1, -1]
		guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
			throw SocketPairError.posix(errno)
		}
		clientDescriptor = descriptors[0]
		peerDescriptor = descriptors[1]
		var noSignal: Int32 = 1
		_ = setsockopt(
			clientDescriptor,
			SOL_SOCKET,
			SO_NOSIGPIPE,
			&noSignal,
			socklen_t(MemoryLayout<Int32>.size)
		)
		_ = setsockopt(
			peerDescriptor,
			SOL_SOCKET,
			SO_NOSIGPIPE,
			&noSignal,
			socklen_t(MemoryLayout<Int32>.size)
		)
		let flags = fcntl(clientDescriptor, F_GETFL)
		guard flags >= 0, fcntl(clientDescriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
			let code = errno
			close(clientDescriptor)
			close(peerDescriptor)
			throw SocketPairError.posix(code)
		}
	}

	func closePeer() {
		close(peerDescriptor)
	}

	func send(_ opcode: DiscordIPCOpcode, json: String) throws {
		let frame = try DiscordIPCFrameCodec.encode(
			DiscordIPCFrame(opcode: opcode, payload: Data(json.utf8)),
			maximumPayloadBytes: 4_096
		)
		try frame.withUnsafeBytes { bytes in
			var offset = 0
			while offset < bytes.count {
				let count = write(peerDescriptor, bytes.baseAddress! + offset, bytes.count - offset)
				guard count > 0 else { throw SocketPairError.posix(errno) }
				offset += count
			}
		}
	}

	/// Blocks until a frame with `opcode` arrives, skipping others. Returns nil on end of file.
	func readFrame(opcode: DiscordIPCOpcode) throws -> DiscordIPCFrame? {
		while true {
			while let frame = try DiscordIPCFrameCodec.decode(
				from: &received, maximumPayloadBytes: 4_096)
			{
				if frame.opcode == opcode { return frame }
			}
			var chunk = [UInt8](repeating: 0, count: 1_024)
			let count = read(peerDescriptor, &chunk, chunk.count)
			if count == 0 { return nil }
			guard count > 0 else { throw SocketPairError.posix(errno) }
			received.append(contentsOf: chunk.prefix(count))
		}
	}
}

/// A clock whose sleeps end only on cancellation, so a handshake timeout never fires.
private final class SuspendedClock: Clock, Sendable {
	typealias Instant = TestClockInstant

	var now: Instant { Instant(offset: .zero) }
	var minimumResolution: Duration { .nanoseconds(1) }

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		let (stream, continuation) = AsyncStream<Never>.makeStream()
		for await _ in stream {}
		continuation.finish()
		try Task.checkCancellation()
	}
}
