// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsGameRuntime

private func littleEndian(_ value: Int64) -> [UInt8] {
	withUnsafeBytes(of: value.littleEndian) { Array($0) }
}

/// A hand-built RTBSDF01 patch from "ABCDEFGH" to "ABDDxyzFI!E" with three control triples.
///
/// 1. add 4 (diff 00 00 01 00: "ABCD" becomes "ABDD"), copy "xyz", seek +2 (old offset 4 to 6).
/// 2. add 2 (diff FF 01: "GH" becomes "FI"), copy "!", seek -6 (old offset 8 to 2).
/// 3. add 1 (diff 02: "C" becomes "E"), copy nothing, seek 0.
private func vectorPatch(
	newSize: Int64 = 11, firstAdd: Int64 = 4, trailing: [UInt8] = []
) -> [UInt8] {
	var patch = Array("RTBSDF01".utf8)
	patch += littleEndian(newSize) + littleEndian(3)
	patch += littleEndian(firstAdd) + littleEndian(3) + littleEndian(2)
	patch += littleEndian(2) + littleEndian(1) + littleEndian(-6)
	patch += littleEndian(1) + littleEndian(0) + littleEndian(0)
	patch += [0x00, 0x00, 0x01, 0x00, 0xFF, 0x01, 0x02]
	patch += Array("xyz!".utf8)
	return patch + trailing
}

private let vectorOld = Array("ABCDEFGH".utf8)

extension [UInt8] {
	fileprivate init(hexadecimal: String) {
		let digits = Array(hexadecimal.utf8).map { UInt8($0 <= 57 ? $0 - 48 : $0 - 87) }
		self = stride(from: 0, to: digits.count, by: 2).map { digits[$0] << 4 | digits[$0 + 1] }
	}
}

private func apply(_ patch: [UInt8], to old: [UInt8]) throws -> [UInt8] {
	try patch.withUnsafeBytes { patchBytes in
		try old.withUnsafeBytes { oldBytes in
			try RuntimeBinaryPatch.apply(patch: patchBytes, to: oldBytes, maximumNewSize: 1_024)
		}
	}
}

struct RuntimeBinaryPatchTests {
	/// The vector published in the runtime repository's `docs/runtime-format.md`.
	private static let publishedVector = [UInt8](
		hexadecimal:
			"5254425344463031" + "0900000000000000" + "0100000000000000" + "0800000000000000"
			+ "0100000000000000" + "0000000000000000" + "0000150000000000" + "21")

	@Test(arguments: [
		(patch: vectorPatch(), old: vectorOld, expected: "ABDDxyzFI!E"),
		(patch: publishedVector, old: vectorOld, expected: "ABXDEFGH!"),
	])
	func appliesKnownVectorsToExactBytes(patch: [UInt8], old: [UInt8], expected: String) throws {
		let result = try apply(patch, to: old)

		#expect(String(decoding: result, as: UTF8.self) == expected)
	}

	@Test(arguments: [
		(label: "negative add", patch: vectorPatch(firstAdd: -1), old: vectorOld),
		(label: "read past the old file", patch: vectorPatch(), old: Array(vectorOld.prefix(5))),
		(label: "trailing bytes", patch: vectorPatch(trailing: [0]), old: vectorOld),
		(label: "new size too large", patch: vectorPatch(newSize: 12), old: vectorOld),
		(label: "new size too small", patch: vectorPatch(newSize: 10), old: vectorOld),
		(label: "truncated streams", patch: Array(vectorPatch().dropLast()), old: vectorOld),
		(
			label: "bad magic", patch: Array("RTBSDF02".utf8) + vectorPatch().dropFirst(8),
			old: vectorOld
		),
	])
	func rejectsMalformedPatches(label: String, patch: [UInt8], old: [UInt8]) {
		#expect(throws: RuntimeDeltaError.self, "\(label)") {
			_ = try apply(patch, to: old)
		}
	}
}
