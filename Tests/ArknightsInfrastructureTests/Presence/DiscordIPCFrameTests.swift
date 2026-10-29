// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsInfrastructure

struct DiscordIPCFrameTests {
	@Test
	func roundTripsFramesAndRejectsOversizedPayloads() throws {
		let payload = Data(#"{"v":1,"client_id":"1539589207381770261"}"#.utf8)
		let frame = DiscordIPCFrame(opcode: .handshake, payload: payload)

		let encoded = try DiscordIPCFrameCodec.encode(frame, maximumPayloadBytes: 128)
		#expect(encoded.count == DiscordIPCFrameCodec.headerByteCount + payload.count)
		#expect(encoded.prefix(4) == Data([0, 0, 0, 0]))
		#expect(
			encoded.dropFirst(4).prefix(4) == Data(UInt32(payload.count).littleEndian.bytes))

		var buffer = encoded
		#expect(
			try DiscordIPCFrameCodec.decode(from: &buffer, maximumPayloadBytes: 128) == frame)
		#expect(buffer.isEmpty)
		#expect(try DiscordIPCFrameCodec.decode(from: &buffer, maximumPayloadBytes: 128) == nil)

		#expect(throws: DiscordIPCFrameError.payloadTooLarge(maximumBytes: 8)) {
			try DiscordIPCFrameCodec.encode(
				DiscordIPCFrame(opcode: .frame, payload: Data(repeating: 0, count: 9)),
				maximumPayloadBytes: 8
			)
		}

		// The length header fails before the claimed payload arrives.
		var oversizedHeader = Data([1, 0, 0, 0, 9, 0, 0, 0])
		#expect(throws: DiscordIPCFrameError.payloadTooLarge(maximumBytes: 8)) {
			try DiscordIPCFrameCodec.decode(from: &oversizedHeader, maximumPayloadBytes: 8)
		}
	}

	@Test
	func activityFrameUsesMillisecondsAndClearsWithNull() throws {
		let activity = DiscordIPCActivity(
			details: "Playing Arknights",
			state: "Global",
			timestamps: DiscordIPCTimestamps(start: 1_700_000_000_000),
			assets: DiscordIPCAssets(
				largeImage: "https://example.com/icon.png",
				largeText: "Arknights macOS Client"
			),
			buttons: [
				DiscordIPCButton(label: "Website", url: "https://example.com/")
			]
		)
		var buffer = try DiscordIPCConnection.activityFrame(
			activity,
			pid: 42,
			maximumPayloadBytes: 1_024
		)
		let frame = try DiscordIPCFrameCodec.decode(from: &buffer, maximumPayloadBytes: 1_024)
		#expect(frame?.opcode == .frame)

		let payloadData = try #require(frame?.payload)
		let command = try #require(
			try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
		)
		#expect(command["cmd"] as? String == "SET_ACTIVITY")
		let args = try #require(command["args"] as? [String: Any])
		#expect(args["pid"] as? Int == 42)
		let payload = try #require(args["activity"] as? [String: Any])
		#expect(payload["details"] as? String == "Playing Arknights")
		#expect(payload["state"] as? String == "Global")
		let timestamps = try #require(payload["timestamps"] as? [String: Any])
		#expect(timestamps["start"] as? Int == 1_700_000_000_000)
		let assets = try #require(payload["assets"] as? [String: Any])
		#expect(assets["large_image"] as? String == "https://example.com/icon.png")
		#expect(assets["large_text"] as? String == "Arknights macOS Client")
		let buttons = try #require(payload["buttons"] as? [[String: Any]])
		#expect(buttons.first?["label"] as? String == "Website")
		#expect(buttons.first?["url"] as? String == "https://example.com/")

		var clearBuffer = try DiscordIPCConnection.activityFrame(
			nil,
			pid: 42,
			maximumPayloadBytes: 1_024
		)
		let clearFrame = try DiscordIPCFrameCodec.decode(
			from: &clearBuffer,
			maximumPayloadBytes: 1_024
		)
		let clearPayload = try #require(clearFrame?.payload)
		let clearCommand = try #require(
			try JSONSerialization.jsonObject(with: clearPayload) as? [String: Any]
		)
		let clearArgs = try #require(clearCommand["args"] as? [String: Any])
		#expect(clearArgs["activity"] is NSNull)
	}
}

extension FixedWidthInteger {
	fileprivate var bytes: [UInt8] {
		withUnsafeBytes(of: self) { Array($0) }
	}
}
