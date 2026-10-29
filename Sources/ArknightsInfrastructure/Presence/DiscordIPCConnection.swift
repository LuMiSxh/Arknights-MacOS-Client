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
/// One instance owns one socket. The caller creates a new connection for each attempt. State is
/// confined to `queue`; async methods return through checked continuations resumed on that queue.
package final class DiscordIPCConnection: @unchecked Sendable {
	private let queue = DispatchQueue(label: "com.lumisxh.arknights-client.discord-ipc")
	private let maximumPayloadBytes: Int
	private let handshakeTimeout: Duration
	private let socketURLs: [URL]
	private var descriptor: Int32 = -1
	private var readSource: DispatchSourceRead?
	private var handshakeTimer: DispatchSourceTimer?
	private var buffer = Data()
	private var handshakeContinuation: CheckedContinuation<Void, any Error>?
	private var disconnectContinuations: [CheckedContinuation<Void, Never>] = []
	private var isClosed = false
	private var isReady = false

	package init(
		maximumPayloadBytes: Int,
		handshakeTimeout: Duration,
		socketURLs: [URL]? = nil
	) {
		self.maximumPayloadBytes = maximumPayloadBytes
		self.handshakeTimeout = handshakeTimeout
		self.socketURLs = socketURLs ?? DiscordIPCSocket.candidateURLs()
	}

	deinit {
		handshakeTimer?.cancel()
		readSource?.cancel()
	}

	/// Connects and returns after Discord sends the `READY` dispatch.
	package func connect(clientID: String) async throws {
		let handshake = try Self.handshakeFrame(
			clientID: clientID,
			maximumPayloadBytes: maximumPayloadBytes
		)
		try await withCheckedThrowingContinuation {
			(continuation: CheckedContinuation<Void, any Error>) in
			beginConnect(handshake, continuation: continuation)
		}
	}

	private func beginConnect(
		_ handshake: Data,
		continuation: CheckedContinuation<Void, any Error>
	) {
		queue.async { [self] in
			guard !isClosed else {
				continuation.resume(throwing: DiscordIPCError.connectionClosed)
				return
			}
			do {
				let fd = try Self.openSocket(at: socketURLs)
				descriptor = fd
				installReadSource(descriptor: fd)
				try writeFrame(handshake)
				handshakeContinuation = continuation
				startHandshakeTimer()
			} catch {
				closeLocked(error: error)
				continuation.resume(throwing: error)
			}
		}
	}

	/// Sends one `SET_ACTIVITY` command. A nil activity clears presence.
	package func setActivity(_ activity: DiscordIPCActivity?, pid: Int32) async throws {
		let frame = try Self.activityFrame(
			activity,
			pid: pid,
			maximumPayloadBytes: maximumPayloadBytes
		)
		try await withCheckedThrowingContinuation {
			(continuation: CheckedContinuation<Void, any Error>) in
			writeActivity(frame, continuation: continuation)
		}
	}

	private func writeActivity(
		_ frame: Data,
		continuation: CheckedContinuation<Void, any Error>
	) {
		queue.async { [self] in
			guard !isClosed, isReady else {
				continuation.resume(throwing: DiscordIPCError.connectionClosed)
				return
			}
			do {
				try writeFrame(frame)
				continuation.resume()
			} catch {
				closeLocked(error: error)
				continuation.resume(throwing: error)
			}
		}
	}

	/// Returns when Discord closes the socket or the caller disconnects.
	package func waitForDisconnect() async {
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			queue.async { [self] in
				if isClosed {
					continuation.resume()
				} else {
					disconnectContinuations.append(continuation)
				}
			}
		}
	}

	package func disconnect() async {
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			queue.async { [self] in
				closeLocked(error: nil)
				continuation.resume()
			}
		}
	}

	private func installReadSource(descriptor fd: Int32) {
		let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
		source.setEventHandler { [weak self] in
			self?.readAvailable()
		}
		source.setCancelHandler {
			close(fd)
		}
		readSource = source
		source.resume()
	}

	private func readAvailable() {
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
						handle(frame)
					}
				} catch {
					closeLocked(error: error)
					return
				}
				continue
			}
			if count == 0 {
				closeLocked(error: DiscordIPCError.connectionClosed)
				return
			}
			if errno == EINTR { continue }
			if errno == EAGAIN || errno == EWOULDBLOCK { return }
			closeLocked(error: DiscordIPCError.readFailed(errno))
			return
		}
	}

	private func handle(_ frame: DiscordIPCFrame) {
		switch frame.opcode {
		case .frame:
			handleJSON(frame.payload)
		case .ping:
			do {
				let pong = try DiscordIPCFrameCodec.encode(
					DiscordIPCFrame(opcode: .pong, payload: frame.payload),
					maximumPayloadBytes: maximumPayloadBytes
				)
				try writeFrame(pong)
			} catch {
				closeLocked(error: error)
			}
		case .close:
			closeLocked(error: DiscordIPCError.connectionClosed)
		case .handshake, .pong:
			break
		}
	}

	private func handleJSON(_ payload: Data) {
		do {
			guard
				let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
				let event = object["evt"] as? String
			else { return }
			switch event {
			case "READY":
				completeHandshake()
			case "ERROR":
				let data = object["data"] as? [String: Any]
				let code = data?["code"] as? Int ?? 0
				let message = data?["message"] as? String ?? "Discord refused the command"
				if handshakeContinuation != nil {
					closeLocked(error: DiscordIPCError.discordError(code: code, message: message))
				}
			default:
				break
			}
		} catch {
			closeLocked(error: DiscordIPCError.invalidMessage)
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
		let timer = DispatchSource.makeTimerSource(queue: queue)
		timer.schedule(deadline: .now() + Self.dispatchInterval(for: handshakeTimeout))
		timer.setEventHandler { [weak self] in
			self?.closeLocked(error: DiscordIPCError.handshakeTimedOut)
		}
		handshakeTimer = timer
		timer.resume()
	}

	private func writeFrame(_ frame: Data) throws {
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
					throw DiscordIPCError.writeFailed(errno)
				}
				guard count > 0 else { throw DiscordIPCError.writeFailed(EIO) }
				offset += count
			}
		}
	}

	private func closeLocked(error: (any Error)?) {
		guard !isClosed else { return }
		isClosed = true
		isReady = false
		handshakeTimer?.cancel()
		handshakeTimer = nil
		if let readSource {
			readSource.cancel()
			self.readSource = nil
		} else if descriptor >= 0 {
			close(descriptor)
		}
		descriptor = -1
		buffer.removeAll(keepingCapacity: false)

		let handshake = handshakeContinuation
		handshakeContinuation = nil
		handshake?.resume(throwing: error ?? DiscordIPCError.connectionClosed)

		let waiters = disconnectContinuations
		disconnectContinuations.removeAll()
		for waiter in waiters {
			waiter.resume()
		}
	}

	private static func openSocket(at urls: [URL]) throws -> Int32 {
		for url in urls {
			let fd = socket(AF_UNIX, SOCK_STREAM, 0)
			guard fd >= 0 else { throw DiscordIPCError.socketUnavailable }
			var noSignal: Int32 = 1
			guard
				setsockopt(
					fd,
					SOL_SOCKET,
					SO_NOSIGPIPE,
					&noSignal,
					socklen_t(MemoryLayout<Int32>.size)
				) == 0
			else {
				close(fd)
				continue
			}
			if connect(fd, to: url) {
				let flags = fcntl(fd, F_GETFL)
				guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
					close(fd)
					continue
				}
				return fd
			}
			close(fd)
		}
		throw DiscordIPCError.socketUnavailable
	}

	private static func connect(_ fd: Int32, to url: URL) -> Bool {
		let path = Array(url.path.utf8)
		let pathCapacity = MemoryLayout.size(ofValue: sockaddr_un().sun_path)
		guard path.count < pathCapacity else { return false }

		var address = sockaddr_un()
		address.sun_family = sa_family_t(AF_UNIX)
		address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
		withUnsafeMutableBytes(of: &address.sun_path) { bytes in
			path.withUnsafeBytes { bytes.copyBytes(from: $0) }
			bytes[path.count] = 0
		}
		let length = socklen_t(MemoryLayout<sockaddr_un>.size)
		return withUnsafePointer(to: &address) { pointer in
			pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
				Darwin.connect(fd, socketAddress, length) == 0
			}
		}
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

	private static func dispatchInterval(for duration: Duration) -> DispatchTimeInterval {
		let components = duration.components
		let nanoseconds =
			components.seconds * 1_000_000_000 + components.attoseconds / 1_000_000_000
		return .nanoseconds(Int(clamping: nanoseconds))
	}
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
