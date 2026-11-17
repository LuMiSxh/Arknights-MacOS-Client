// SPDX-License-Identifier: MPL-2.0

import Darwin
import Dispatch
import Foundation

enum DiscordIPCError: Error, Sendable {
	case socketUnavailable
	case writeFailed(Int32)
	case readFailed(Int32)
	case connectionClosed
	case handshakeTimedOut
	case invalidMessage
	case discordError(code: Int, message: String)
}

package struct DiscordIPCTimestamps: Encodable, Equatable, Sendable {
	/// Milliseconds since the Unix epoch. Discord renders the elapsed time from this value.
	package var start: Int64

	package init(start: Int64) {
		self.start = start
	}
}

package struct DiscordIPCActivity: Encodable, Equatable, Sendable {
	package var details: String
	package var state: String?
	package var timestamps: DiscordIPCTimestamps?
	package var assets: DiscordIPCAssets?
	package var buttons: [DiscordIPCButton]?

	package init(
		details: String,
		state: String? = nil,
		timestamps: DiscordIPCTimestamps? = nil,
		assets: DiscordIPCAssets? = nil,
		buttons: [DiscordIPCButton]? = nil
	) {
		self.details = details
		self.state = state
		self.timestamps = timestamps
		self.assets = assets
		self.buttons = buttons
	}
}

package struct DiscordIPCAssets: Encodable, Equatable, Sendable {
	package var smallImage: String?
	package var largeImage: String?
	package var smallText: String?
	package var largeText: String?

	package init(
		smallImage: String? = nil,
		largeImage: String? = nil,
		smallText: String? = nil,
		largeText: String? = nil
	) {
		self.smallImage = smallImage
		self.largeImage = largeImage
		self.smallText = smallText
		self.largeText = largeText
	}

	private enum CodingKeys: String, CodingKey {
		case smallImage = "small_image"
		case largeImage = "large_image"
		case smallText = "small_text"
		case largeText = "large_text"
	}
}

package struct DiscordIPCButton: Encodable, Equatable, Sendable {
	package var label: String
	package var url: String

	package init(label: String, url: String) {
		self.label = label
		self.url = url
	}
}

/// Opens Discord's local IPC socket, performs the handshake, and sends activity updates.
///
/// One instance owns one socket. The caller creates a new connection for each attempt. The actor
/// confines the socket state machine; a dispatch source delivers reads and blocking socket work
/// runs on concurrent helpers.
package actor DiscordIPCConnection {
	private let maximumPayloadBytes: Int
	private let handshakeTimeout: Duration
	private let clock: any Clock<Duration>
	private let reportProtocolError: @Sendable (String) -> Void
	private let openSocket: @Sendable () throws -> Int32
	private let sourceQueue = DispatchQueue(
		label: "com.lumisxh.arknights-client.discord-ipc.events")
	private var descriptor: Int32 = -1
	private var readSource: DispatchSourceRead?
	private var handshakeTimer: Task<Void, Never>?
	private var buffer = Data()
	private var handshakeContinuation: CheckedContinuation<Void, any Error>?
	private var disconnectContinuations: [CheckedContinuation<Void, Never>] = []
	private var pendingWrites: [PendingWrite] = []
	private var isDrainingWrites = false
	private var isWritingToDescriptor = false
	private var isClosePending = false
	private var isClosed = false
	private var isReady = false

	private struct PendingWrite {
		let data: Data
		let continuation: CheckedContinuation<Void, any Error>
	}

	// Actors cannot have convenience initializers, so both initializers set the stored properties.
	package init(
		maximumPayloadBytes: Int,
		handshakeTimeout: Duration,
		socketURLs: [URL]? = nil,
		clock: any Clock<Duration> = ContinuousClock(),
		reportProtocolError: @escaping @Sendable (String) -> Void = { _ in }
	) {
		let urls = socketURLs ?? DiscordIPCSocket.candidateURLs()
		self.maximumPayloadBytes = maximumPayloadBytes
		self.handshakeTimeout = handshakeTimeout
		self.clock = clock
		self.reportProtocolError = reportProtocolError
		self.openSocket = { try Self.openSocket(at: urls) }
	}

	// Tests supply a socketpair descriptor because the test harness denies bind(2).
	init(
		maximumPayloadBytes: Int,
		handshakeTimeout: Duration,
		clock: any Clock<Duration> = ContinuousClock(),
		reportProtocolError: @escaping @Sendable (String) -> Void = { _ in },
		openSocket: @escaping @Sendable () throws -> Int32
	) {
		self.maximumPayloadBytes = maximumPayloadBytes
		self.handshakeTimeout = handshakeTimeout
		self.clock = clock
		self.reportProtocolError = reportProtocolError
		self.openSocket = openSocket
	}

	deinit {
		handshakeTimer?.cancel()
		readSource?.cancel()
		if descriptor >= 0 {
			Darwin.close(descriptor)
		}
	}

	/// Longest wait for a full socket buffer to drain before a write fails.
	private static let writeStallTimeoutMilliseconds: Int32 = 1_000

	/// Connects and returns after Discord sends the `READY` dispatch.
	package func connect(clientID: String) async throws {
		let handshake = try Self.handshakeFrame(
			clientID: clientID,
			maximumPayloadBytes: maximumPayloadBytes
		)
		try await beginConnect(handshake)
	}

	private func beginConnect(_ handshake: Data) async throws {
		guard !isClosed else { throw DiscordIPCError.connectionClosed }
		let socketDescriptor: Int32
		do {
			socketDescriptor = try await Self.openedDescriptor(by: openSocket)
		} catch {
			close(error: error)
			throw error
		}
		guard !isClosed else {
			Darwin.close(socketDescriptor)
			throw DiscordIPCError.connectionClosed
		}
		descriptor = socketDescriptor
		installReadSource(descriptor: socketDescriptor)
		try await withCheckedThrowingContinuation {
			(continuation: CheckedContinuation<Void, any Error>) in
			handshakeContinuation = continuation
			startHandshakeTimer()
			Task { await self.sendHandshake(handshake) }
		}
	}

	private func sendHandshake(_ frame: Data) async {
		do {
			try await writeFrame(frame)
		} catch {
			close(error: error)
		}
	}

	/// Sends one `SET_ACTIVITY` command. A nil activity clears presence.
	package func setActivity(_ activity: DiscordIPCActivity?, pid: Int32) async throws {
		let frame = try Self.activityFrame(
			activity,
			pid: pid,
			maximumPayloadBytes: maximumPayloadBytes
		)
		guard !isClosed, isReady else { throw DiscordIPCError.connectionClosed }
		do {
			try await writeFrame(frame)
		} catch {
			close(error: error)
			throw error
		}
	}

	/// Returns when Discord closes the socket or the caller disconnects.
	package func waitForDisconnect() async {
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			if isClosed {
				continuation.resume()
			} else {
				disconnectContinuations.append(continuation)
			}
		}
	}

	package func disconnect() async {
		close(error: nil)
	}

	private func installReadSource(descriptor fd: Int32) {
		let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: sourceQueue)
		source.setEventHandler { [weak self] in
			guard let self else { return }
			Task { await self.readAvailable() }
		}
		readSource = source
		source.resume()
	}

	/// Drains the non-blocking socket; the source delivers readiness and hops into the actor.
	private func readAvailable() async {
		while !isClosed {
			var chunk = Data(count: 4_096)
			let count = chunk.withUnsafeMutableBytes { bytes in
				Darwin.read(descriptor, bytes.baseAddress, bytes.count)
			}
			if count > 0 {
				buffer.append(chunk.prefix(count))
				do {
					while let frame = try DiscordIPCFrameCodec.decode(
						from: &buffer,
						maximumPayloadBytes: maximumPayloadBytes
					) {
						await handle(frame)
						if isClosed { return }
					}
				} catch {
					close(error: error)
					return
				}
				continue
			}
			if count == 0 {
				close(error: DiscordIPCError.connectionClosed)
				return
			}
			if errno == EINTR { continue }
			if errno == EAGAIN || errno == EWOULDBLOCK { return }
			close(error: DiscordIPCError.readFailed(errno))
			return
		}
	}

	private func handle(_ frame: DiscordIPCFrame) async {
		switch frame.opcode {
		case .frame:
			handleJSON(frame.payload)
		case .ping:
			do {
				let pong = try DiscordIPCFrameCodec.encode(
					DiscordIPCFrame(opcode: .pong, payload: frame.payload),
					maximumPayloadBytes: maximumPayloadBytes
				)
				try await writeFrame(pong)
			} catch {
				close(error: error)
			}
		case .close:
			close(error: DiscordIPCError.connectionClosed)
		case .handshake, .pong:
			break
		}
	}

	private func handleJSON(_ payload: Data) {
		do {
			let event = try JSONDecoder().decode(DiscordIPCEvent.self, from: payload)
			guard let name = event.evt else { return }
			switch name {
			case "READY":
				completeHandshake()
			case "ERROR":
				let code = event.data?.code ?? 0
				let message = event.data?.message ?? "Discord refused the command"
				if handshakeContinuation != nil {
					close(error: DiscordIPCError.discordError(code: code, message: message))
				} else {
					reportProtocolError("Discord reported error \(code): \(message)")
				}
			default:
				break
			}
		} catch {
			close(error: DiscordIPCError.invalidMessage)
		}
	}

	private func completeHandshake() {
		handshakeTimer?.cancel()
		handshakeTimer = nil
		isReady = true
		let continuation = handshakeContinuation
		handshakeContinuation = nil
		continuation?.resume()
	}

	private func startHandshakeTimer() {
		let clock = clock
		let timeout = handshakeTimeout
		handshakeTimer = Task { [weak self] in
			do {
				try await clock.sleep(for: timeout)
			} catch {
				return
			}
			await self?.handshakeDidTimeOut()
		}
	}

	private func handshakeDidTimeOut() {
		guard handshakeContinuation != nil else { return }
		close(error: DiscordIPCError.handshakeTimedOut)
	}

	/// Opens the socket off the cooperative pool because `connect(2)` may block.
	@concurrent
	private static func openedDescriptor(
		by openSocket: @Sendable () throws -> Int32
	) async throws -> Int32 {
		try openSocket()
	}

	/// Writes every byte off the cooperative pool, polling when the full socket buffer drains.
	@concurrent
	private static func writeAll(_ frame: Data, to descriptor: Int32) async throws {
		try frame.withUnsafeBytes { bytes in
			guard let baseAddress = bytes.baseAddress else { return }
			var offset = 0
			while offset < bytes.count {
				let count = Darwin.write(
					descriptor,
					baseAddress.advanced(by: offset),
					bytes.count - offset
				)
				if count < 0 {
					if errno == EINTR { continue }
					if errno == EAGAIN || errno == EWOULDBLOCK {
						try waitUntilWritable(descriptor)
						continue
					}
					throw DiscordIPCError.writeFailed(errno)
				}
				guard count > 0 else { throw DiscordIPCError.writeFailed(EIO) }
				offset += count
			}
		}
	}

	/// Blocks the writing helper until the socket accepts more bytes, for at most the stall bound.
	private static func waitUntilWritable(_ descriptor: Int32) throws {
		var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
		while true {
			let ready = poll(&pollDescriptor, 1, writeStallTimeoutMilliseconds)
			if ready > 0 { return }
			if ready == 0 { throw DiscordIPCError.writeFailed(ETIMEDOUT) }
			if errno != EINTR { throw DiscordIPCError.writeFailed(errno) }
		}
	}

	/// Queues a frame so writes reach the socket one at a time.
	private func writeFrame(_ frame: Data) async throws {
		try await withCheckedThrowingContinuation {
			(continuation: CheckedContinuation<Void, any Error>) in
			guard !isClosed else {
				continuation.resume(throwing: DiscordIPCError.connectionClosed)
				return
			}
			pendingWrites.append(PendingWrite(data: frame, continuation: continuation))
			guard !isDrainingWrites else { return }
			isDrainingWrites = true
			Task { await self.drainWrites() }
		}
	}

	private func drainWrites() async {
		while let write = pendingWrites.first {
			pendingWrites.removeFirst()
			guard !isClosed, descriptor >= 0 else {
				let error = DiscordIPCError.connectionClosed
				write.continuation.resume(throwing: error)
				failPendingWrites(with: error)
				isDrainingWrites = false
				return
			}
			isWritingToDescriptor = true
			do {
				try await Self.writeAll(write.data, to: descriptor)
			} catch {
				isWritingToDescriptor = false
				if isClosePending {
					closeDescriptor()
				}
				close(error: error)
				write.continuation.resume(throwing: error)
				failPendingWrites(with: error)
				isDrainingWrites = false
				return
			}
			isWritingToDescriptor = false
			write.continuation.resume()
			if isClosePending {
				closeDescriptor()
			}
		}
		isDrainingWrites = false
	}

	private func failPendingWrites(with error: any Error) {
		let pending = pendingWrites
		pendingWrites.removeAll()
		for write in pending {
			write.continuation.resume(throwing: error)
		}
	}

	private func close(error: (any Error)?) {
		guard !isClosed else { return }
		isClosed = true
		isReady = false
		handshakeTimer?.cancel()
		handshakeTimer = nil
		buffer.removeAll(keepingCapacity: false)

		let handshake = handshakeContinuation
		handshakeContinuation = nil
		handshake?.resume(throwing: error ?? DiscordIPCError.connectionClosed)

		let waiters = disconnectContinuations
		disconnectContinuations.removeAll()
		for waiter in waiters {
			waiter.resume()
		}

		// Keep the descriptor open until the offloaded write returns, so it never targets a reused fd.
		if isWritingToDescriptor {
			isClosePending = true
		} else {
			closeDescriptor()
		}
	}

	private func closeDescriptor() {
		isClosePending = false
		if let readSource {
			readSource.cancel()
			self.readSource = nil
		}
		if descriptor >= 0 {
			Darwin.close(descriptor)
			descriptor = -1
		}
	}

	private static func openSocket(at urls: [URL]) throws -> Int32 {
		for url in urls {
			if let fd = openSocket(to: url) { return fd }
		}
		throw DiscordIPCError.socketUnavailable
	}

	/// Returns a connected, non-blocking socket, or nil when `url` does not accept one.
	private static func openSocket(to url: URL) -> Int32? {
		let path = Array(url.path.utf8)
		let pathCapacity = MemoryLayout.size(ofValue: sockaddr_un().sun_path)
		guard path.count < pathCapacity else { return nil }

		let fd = socket(AF_UNIX, SOCK_STREAM, 0)
		guard fd >= 0 else { return nil }
		var noSignal: Int32 = 1
		guard
			setsockopt(
				fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0
		else {
			Darwin.close(fd)
			return nil
		}

		var address = sockaddr_un()
		address.sun_family = sa_family_t(AF_UNIX)
		address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
		withUnsafeMutableBytes(of: &address.sun_path) { bytes in
			path.withUnsafeBytes { bytes.copyBytes(from: $0) }
			bytes[path.count] = 0
		}
		let length = socklen_t(MemoryLayout<sockaddr_un>.size)
		let connected = withUnsafePointer(to: &address) { pointer in
			pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
				Darwin.connect(fd, socketAddress, length) == 0
			}
		}
		let flags = fcntl(fd, F_GETFL)
		guard connected, flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
			Darwin.close(fd)
			return nil
		}
		return fd
	}

	private static func handshakeFrame(
		clientID: String,
		maximumPayloadBytes: Int
	) throws -> Data {
		let payload = try JSONEncoder().encode(Handshake(v: 1, clientID: clientID))
		return try DiscordIPCFrameCodec.encode(
			DiscordIPCFrame(opcode: .handshake, payload: payload),
			maximumPayloadBytes: maximumPayloadBytes
		)
	}

	static func activityFrame(
		_ activity: DiscordIPCActivity?,
		pid: Int32,
		maximumPayloadBytes: Int
	) throws -> Data {
		let command = SetActivityCommand(
			cmd: "SET_ACTIVITY",
			args: SetActivityArguments(pid: pid, activity: activity),
			nonce: UUID().uuidString
		)
		let payload = try JSONEncoder().encode(command)
		return try DiscordIPCFrameCodec.encode(
			DiscordIPCFrame(opcode: .frame, payload: payload),
			maximumPayloadBytes: maximumPayloadBytes
		)
	}

}

private struct DiscordIPCEvent: Decodable {
	let evt: String?
	let data: DiscordIPCErrorData?
}

private struct DiscordIPCErrorData: Decodable {
	let code: Int?
	let message: String?
}

private struct Handshake: Encodable {
	let v: Int
	let clientID: String

	private enum CodingKeys: String, CodingKey {
		case v
		case clientID = "client_id"
	}
}

private struct SetActivityCommand: Encodable {
	let cmd: String
	let args: SetActivityArguments
	let nonce: String
}

private struct SetActivityArguments: Encodable {
	let pid: Int32
	let activity: DiscordIPCActivity?

	// Discord clears presence only when `activity` is present and null.
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(pid, forKey: .pid)
		if let activity {
			try container.encode(activity, forKey: .activity)
		} else {
			try container.encodeNil(forKey: .activity)
		}
	}

	private enum CodingKeys: String, CodingKey {
		case pid
		case activity
	}
}

/// Discord's socket directories and names. These belong to the upstream protocol.
enum DiscordIPCSocket {
	static let namePrefix = "discord-ipc-"
	static let indices = 0...9

	static func candidateURLs(
		environment: [String: String] = ProcessInfo.processInfo.environment
	) -> [URL] {
		let directories =
			["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP"]
			.compactMap { environment[$0] }
			.filter { !$0.isEmpty } + ["/tmp"]

		var seen = Set<String>()
		var urls: [URL] = []
		for directory in directories {
			let base = URL(filePath: directory, directoryHint: .isDirectory)
			for index in indices {
				let url = base.appending(path: "\(namePrefix)\(index)")
				if seen.insert(url.path).inserted {
					urls.append(url)
				}
			}
		}
		return urls
	}
}
