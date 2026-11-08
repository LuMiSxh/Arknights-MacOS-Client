// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct DiscordIPCConnectionTests {
	@Test
	func eagainKeepsTheConnectionOpenForLaterReads() async throws {
		let pair = try ConnectedSocketPair()
		defer { pair.closePeer() }
		let peer = FakeIPCPeer(descriptor: pair.peerDescriptor)
		let descriptor = pair.clientDescriptor
		let connection = DiscordIPCConnection(
			maximumPayloadBytes: 4_096,
			handshakeTimeout: .seconds(5),
			openSocket: { descriptor }
		)
		let connect = Task { try await connection.connect(clientID: Self.clientID) }

		try peer.send(Self.readyFrame)
		try await connect.value

		// READY drained the socket, so the reader returned on EAGAIN. A later ping must still
		// reach the handler instead of a closed connection.
		let ping = Data(#"{"nonce":"ping"}"#.utf8)
		try peer.send(DiscordIPCFrame(opcode: .ping, payload: ping))

		var reply = try peer.receive()
		while reply.opcode != .pong {
			reply = try peer.receive()
		}
		#expect(reply.payload == ping)
		await connection.disconnect()
	}

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

		do {
			try await connection.connect(clientID: Self.clientID)
			Issue.record("connect returned without a READY dispatch.")
		} catch let error as DiscordIPCError {
			guard case .handshakeTimedOut = error else {
				Issue.record("Expected handshakeTimedOut, got \(error).")
				return
			}
		}
		#expect(clock.sleeps.count == 1)
	}

	private static let clientID = "1539589207381770261"
	private static let readyFrame = DiscordIPCFrame(
		opcode: .frame,
		payload: Data(#"{"cmd":"DISPATCH","evt":"READY","data":{}}"#.utf8)
	)
}

private enum SocketPairError: Error {
	case posix(Int32)
	case timedOut
	case closed
}

/// Two connected AF_UNIX descriptors. The connection end is non-blocking, as a real socket is.
private final class ConnectedSocketPair {
	let clientDescriptor: Int32
	let peerDescriptor: Int32

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
}

private final class FakeIPCPeer {
	private let descriptor: Int32
	private var buffer = Data()

	init(descriptor: Int32) {
		self.descriptor = descriptor
	}

	func send(_ frame: DiscordIPCFrame) throws {
		let data = try DiscordIPCFrameCodec.encode(frame, maximumPayloadBytes: 4_096)
		try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
			guard let base = bytes.baseAddress else { return }
			var offset = 0
			while offset < bytes.count {
				let written = Darwin.write(descriptor, base + offset, bytes.count - offset)
				if written < 0 {
					if errno == EINTR { continue }
					throw SocketPairError.posix(errno)
				}
				offset += written
			}
		}
	}

	func receive() throws -> DiscordIPCFrame {
		while true {
			if let frame = try DiscordIPCFrameCodec.decode(
				from: &buffer,
				maximumPayloadBytes: 4_096
			) {
				return frame
			}
			var ready = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
			guard poll(&ready, 1, 5_000) > 0 else { throw SocketPairError.timedOut }
			var chunk = [UInt8](repeating: 0, count: 4_096)
			let count = chunk.withUnsafeMutableBytes {
				Darwin.read(descriptor, $0.baseAddress, $0.count)
			}
			guard count > 0 else { throw SocketPairError.closed }
			buffer.append(contentsOf: chunk.prefix(count))
		}
	}
}
