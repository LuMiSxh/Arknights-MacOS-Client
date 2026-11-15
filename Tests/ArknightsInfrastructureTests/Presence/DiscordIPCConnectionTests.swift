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
}

private enum SocketPairError: Error {
	case posix(Int32)
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
