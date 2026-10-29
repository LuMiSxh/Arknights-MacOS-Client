// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Discord RPC opcode. The values come from Discord's IPC contract and are not configuration.
enum DiscordIPCOpcode: UInt32, Sendable {
	case handshake = 0
	case frame = 1
	case close = 2
	case ping = 3
	case pong = 4
}

enum DiscordIPCFrameError: Error, Equatable, Sendable {
	case payloadTooLarge(maximumBytes: Int)
	case unknownOpcode(UInt32)
}

/// One Discord IPC message: an opcode and its UTF-8 JSON payload.
struct DiscordIPCFrame: Equatable, Sendable {
	let opcode: DiscordIPCOpcode
	let payload: Data
}

/// Encodes and decodes Discord's eight-byte header followed by a JSON payload.
///
/// Both header fields are little-endian `UInt32` values: the opcode, then the payload length.
enum DiscordIPCFrameCodec {
	static let headerByteCount = 8

	static func encode(_ frame: DiscordIPCFrame, maximumPayloadBytes: Int) throws -> Data {
		guard frame.payload.count <= maximumPayloadBytes else {
			throw DiscordIPCFrameError.payloadTooLarge(maximumBytes: maximumPayloadBytes)
		}
		var data = Data(capacity: headerByteCount + frame.payload.count)
		appendLittleEndian(UInt32(frame.opcode.rawValue), to: &data)
		appendLittleEndian(UInt32(frame.payload.count), to: &data)
		data.append(frame.payload)
		return data
	}

	/// Removes and returns one frame from `buffer`, or returns nil until every byte arrives.
	///
	/// A header that declares an oversized payload fails before Discord sends the payload, so a
	/// misbehaving peer cannot make the reader hold an unbounded message.
	static func decode(
		from buffer: inout Data,
		maximumPayloadBytes: Int
	) throws -> DiscordIPCFrame? {
		guard buffer.count >= headerByteCount else { return nil }
		let opcodeValue = readLittleEndian(buffer, at: 0)
		let payloadLength = Int(readLittleEndian(buffer, at: 4))
		guard payloadLength <= maximumPayloadBytes else {
			throw DiscordIPCFrameError.payloadTooLarge(maximumBytes: maximumPayloadBytes)
		}
		guard let opcode = DiscordIPCOpcode(rawValue: opcodeValue) else {
			throw DiscordIPCFrameError.unknownOpcode(opcodeValue)
		}
		let frameByteCount = headerByteCount + payloadLength
		guard buffer.count >= frameByteCount else { return nil }
		let payload = Data(buffer.dropFirst(headerByteCount).prefix(payloadLength))
		buffer = Data(buffer.dropFirst(frameByteCount))
		return DiscordIPCFrame(opcode: opcode, payload: payload)
	}

	private static func appendLittleEndian(_ value: UInt32, to data: inout Data) {
		let littleEndian = value.littleEndian
		withUnsafeBytes(of: littleEndian) { data.append(contentsOf: $0) }
	}

	private static func readLittleEndian(_ data: Data, at offset: Int) -> UInt32 {
		let value = data.withUnsafeBytes { bytes in
			bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
		}
		return UInt32(littleEndian: value)
	}
}
