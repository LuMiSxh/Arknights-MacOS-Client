// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsInfrastructure

struct DiscordIPCFrameTests {
	@Test
	func activityFrameSendsSetActivityAndClearsPresenceWithANullActivity() throws {
		let activity = DiscordIPCActivity(details: "Playing Arknights")
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
