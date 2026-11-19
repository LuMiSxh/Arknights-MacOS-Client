// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

protocol DiscordIPCTransport: Sendable {
	func connect(clientID: String) async throws
	func setActivity(_ activity: DiscordIPCActivity?, pid: Int32) async throws
	func waitForDisconnect() async
	func disconnect() async
}

extension DiscordIPCConnection: DiscordIPCTransport {}

enum DiscordPresenceState: Equatable, Sendable {
	case disabled
	case idle
	case connecting
	case active(sessionID: UUID)
	case reconnecting
}

struct DiscordPresenceRequest: Equatable, Sendable {
	let sessionID: UUID
	let regionName: String
	let startedAt: Date
}

enum DiscordPresenceIntent: Equatable, Sendable {
	case disabled
	case idle
	case playing(DiscordPresenceRequest)
}

/// Owns the Discord IPC connection and rejects results from replaced sessions.
///
/// Every transition takes a generation token before it suspends. A newer intent increments the
/// token, so a slow connection from an older game session cannot publish or clear newer presence.
actor DiscordPresenceSession {
	private(set) var state: DiscordPresenceState = .idle

	private let clientID: String
	private let processIdentifier: Int32
	private let log: LauncherLog
	private let clock: any Clock<Duration>
	private let makeTransport: @Sendable () -> any DiscordIPCTransport
	private let connectionAttempts: Int
	private let initialBackoff: Duration
	private let maximumBackoff: Duration

	private var desired: DiscordPresenceRequest?
	private var connection: (any DiscordIPCTransport)?
	private var monitorTask: Task<Void, Never>?
	private var generation: UInt64 = 0

	init(
		clientID: String,
		processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier,
		log: LauncherLog,
		clock: any Clock<Duration> = ContinuousClock(),
		connectionAttempts: Int = AppConstants.Presence.connectionAttempts,
		initialBackoff: Duration = AppConstants.Presence.initialRetryBackoff,
		maximumBackoff: Duration = AppConstants.Presence.maximumRetryBackoff,
		makeTransport: @escaping @Sendable () -> any DiscordIPCTransport
	) {
		self.clientID = clientID
		self.processIdentifier = processIdentifier
		self.log = log
		self.clock = clock
		self.connectionAttempts = connectionAttempts
		self.initialBackoff = initialBackoff
		self.maximumBackoff = maximumBackoff
		self.makeTransport = makeTransport
	}

	func apply(_ intent: DiscordPresenceIntent) async {
		// A replaced task must not reach the actor after its newer intent.
		guard !Task.isCancelled else { return }
		generation &+= 1
		let token = generation
		monitorTask?.cancel()
		monitorTask = nil

		switch intent {
		case .disabled:
			desired = nil
			await clear(token: token, endingState: .disabled)
		case .idle:
			desired = nil
			await clear(token: token, endingState: .idle)
		case .playing(let request):
			desired = request
			if let connection {
				await present(request, over: connection, token: token)
			} else {
				state = .connecting
				guard let transport = await connectedTransport(token: token) else {
					if token == generation { state = .idle }
					return
				}
				guard token == generation, desired != nil else {
					await transport.disconnect()
					return
				}
				connection = transport
				await present(request, over: transport, token: token)
			}
		}
	}

	private func present(
		_ request: DiscordPresenceRequest,
		over connection: any DiscordIPCTransport,
		token: UInt64
	) async {
		let activity = DiscordIPCActivity(
			details: "Playing Arknights",
			state: request.regionName,
			timestamps: DiscordIPCTimestamps(
				start: Int64((request.startedAt.timeIntervalSince1970 * 1_000).rounded())
			),
			assets: DiscordIPCAssets(
				smallImage: SupportLinks.applicationIcon.absoluteString,
				largeImage: nil,
				smallText: "Arknights macOS Client",
				largeText: "Arknights"
			),
			buttons: [
				DiscordIPCButton(
					label: "Website",
					url: SupportLinks.documentationRoot.absoluteString
				)
			]
		)
		do {
			try await connection.setActivity(activity, pid: processIdentifier)
			guard token == generation else { return }
			state = .active(sessionID: request.sessionID)
			monitor(connection, token: token)
		} catch {
			log.error(
				"Discord presence could not update: \(launcherDiagnosticDescription(for: error))"
			)
			guard token == generation else { return }
			self.connection = nil
			await connection.disconnect()
			await reconnect(token: token)
		}
	}

	private func clear(token: UInt64, endingState: DiscordPresenceState) async {
		let existing = connection
		connection = nil
		if let existing {
			do {
				try await existing.setActivity(nil, pid: processIdentifier)
			} catch {
				log.error(
					"Discord presence could not clear: \(launcherDiagnosticDescription(for: error))"
				)
			}
			await existing.disconnect()
		}
		guard token == generation else { return }
		state = endingState
	}

	private func connectedTransport(token: UInt64) async -> (any DiscordIPCTransport)? {
		var backoff = initialBackoff
		for attempt in 1...connectionAttempts {
			guard token == generation, !Task.isCancelled else { return nil }
			let transport = makeTransport()
			do {
				try await transport.connect(clientID: clientID)
				guard token == generation, !Task.isCancelled else {
					await transport.disconnect()
					return nil
				}
				return transport
			} catch {
				await transport.disconnect()
				log.error(
					"Discord presence could not connect (attempt \(attempt)): \(launcherDiagnosticDescription(for: error))"
				)
				guard attempt < connectionAttempts, token == generation, !Task.isCancelled
				else { return nil }
				do {
					try await clock.sleep(for: backoff, tolerance: backoff / 10)
				} catch {
					return nil
				}
				backoff = min(backoff * 2, maximumBackoff)
			}
		}
		return nil
	}

	private func monitor(_ connection: any DiscordIPCTransport, token: UInt64) {
		monitorTask = Task { [weak self] in
			await connection.waitForDisconnect()
			await self?.connectionDidClose(token: token)
		}
	}

	private func connectionDidClose(token: UInt64) async {
		guard token == generation, connection != nil else { return }
		connection = nil
		await reconnect(token: token)
	}

	private func reconnect(token: UInt64) async {
		guard token == generation, let request = desired else { return }
		state = .reconnecting
		guard let transport = await connectedTransport(token: token) else {
			guard token == generation else { return }
			state = .idle
			return
		}
		guard token == generation, desired != nil else {
			await transport.disconnect()
			return
		}
		connection = transport
		await present(request, over: transport, token: token)
	}
}
