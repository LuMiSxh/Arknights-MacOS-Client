// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Failures while reading or applying a runtime delta.
enum RuntimeDeltaError: Error, Equatable, Sendable {
	case invalidPatch(String)
	case invalidManifest(String)
	case unsafePath(String)
	case sourceMismatch(String)
	case resultMismatch(String)
	case cloneFailed(Int32)
}

/// Applies an `RTBSDF01` patch: the bsdiff algorithm with uncompressed streams.
///
/// ```text
/// "RTBSDF01" | u64 newSize | u64 controlCount | controlCount x (i64 add, i64 copy, i64 seek)
///            | diff bytes (sum of add) | extra bytes (sum of copy)
/// ```
///
/// Integers are little-endian. Every read and write is bounds-checked, so a malformed patch
/// throws instead of touching memory outside `old`, the patch, or the result.
enum RuntimeBinaryPatch {
	private static let magic = Array("RTBSDF01".utf8)
	private static let headerSize = 24
	private static let controlSize = 24

	static func apply(
		patch: UnsafeRawBufferPointer,
		to old: UnsafeRawBufferPointer,
		maximumNewSize: Int
	) throws -> [UInt8] {
		guard patch.count >= headerSize, patch.prefix(magic.count).elementsEqual(magic) else {
			throw RuntimeDeltaError.invalidPatch("missing RTBSDF01 header")
		}
		let declaredSize = UInt64(
			littleEndian: patch.loadUnaligned(fromByteOffset: 8, as: UInt64.self))
		guard let newSize = Int(exactly: declaredSize), newSize <= maximumNewSize else {
			throw RuntimeDeltaError.invalidPatch("new size is out of range")
		}
		let declaredCount = UInt64(
			littleEndian: patch.loadUnaligned(fromByteOffset: 16, as: UInt64.self))
		guard let controlCount = Int(exactly: declaredCount) else {
			throw RuntimeDeltaError.invalidPatch("control table exceeds the patch")
		}
		let (controlBytes, controlOverflow) = controlCount.multipliedReportingOverflow(
			by: controlSize)
		guard !controlOverflow, controlBytes <= patch.count - headerSize else {
			throw RuntimeDeltaError.invalidPatch("control table exceeds the patch")
		}

		// Pass one sizes the diff and extra streams, so leftovers and short streams fail up front.
		let diffStart = headerSize + controlBytes
		var addTotal = 0
		var copyTotal = 0
		for index in 0..<controlCount {
			let (add, copy, _) = control(at: headerSize + index * controlSize, in: patch)
			guard add >= 0, copy >= 0 else {
				throw RuntimeDeltaError.invalidPatch("negative length")
			}
			let (nextAdd, addOverflow) = addTotal.addingReportingOverflow(add)
			let (nextCopy, copyOverflow) = copyTotal.addingReportingOverflow(copy)
			guard !addOverflow, !copyOverflow else {
				throw RuntimeDeltaError.invalidPatch("stream length overflows")
			}
			addTotal = nextAdd
			copyTotal = nextCopy
		}
		let available = patch.count - diffStart
		guard addTotal <= available, copyTotal == available - addTotal else {
			throw RuntimeDeltaError.invalidPatch("stream size does not match the patch")
		}
		let extraStart = diffStart + addTotal

		return try [UInt8](unsafeUninitializedCapacity: newSize) { output, initialized in
			var newPos = 0
			var oldPos = 0
			var diffPos = diffStart
			var extraPos = extraStart
			for index in 0..<controlCount {
				let (add, copy, seek) = control(at: headerSize + index * controlSize, in: patch)
				guard add <= newSize - newPos else {
					throw RuntimeDeltaError.invalidPatch("write past the new size")
				}
				if add > 0 {
					guard oldPos >= 0, add <= old.count - oldPos else {
						throw RuntimeDeltaError.invalidPatch("read past the old file")
					}
					let source = old.baseAddress!.assumingMemoryBound(to: UInt8.self) + oldPos
					let diff = patch.baseAddress!.assumingMemoryBound(to: UInt8.self) + diffPos
					let target = output.baseAddress! + newPos
					for offset in 0..<add {
						target[offset] = source[offset] &+ diff[offset]
					}
					newPos += add
					oldPos += add
					diffPos += add
				}
				guard copy <= newSize - newPos else {
					throw RuntimeDeltaError.invalidPatch("write past the new size")
				}
				if copy > 0 {
					(output.baseAddress! + newPos).update(
						from: patch.baseAddress!.assumingMemoryBound(to: UInt8.self) + extraPos,
						count: copy)
					newPos += copy
					extraPos += copy
				}
				let (nextOld, seekOverflow) = oldPos.addingReportingOverflow(seek)
				guard !seekOverflow else {
					throw RuntimeDeltaError.invalidPatch("old offset overflows")
				}
				oldPos = nextOld
			}
			guard newPos == newSize else {
				throw RuntimeDeltaError.invalidPatch("result is shorter than the new size")
			}
			initialized = newSize
		}
	}

	private static func control(
		at offset: Int, in patch: UnsafeRawBufferPointer
	) -> (add: Int, copy: Int, seek: Int) {
		func value(_ position: Int) -> Int {
			Int(Int64(littleEndian: patch.loadUnaligned(fromByteOffset: position, as: Int64.self)))
		}
		return (value(offset), value(offset + 8), value(offset + 16))
	}
}
