// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Builds a plain, uncompressed tar archive; wrap it with `xzCompressed` for the installer.
package struct TarBuilder {
	package private(set) var data = Data()

	package init() {}

	package mutating func append(
		name: String,
		typeFlag: UInt8 = 0x30,
		linkName: String = "",
		mode: Int = 0o644,
		content: Data = Data()
	) {
		var header = [UInt8](repeating: 0, count: 512)
		writeString(name, into: &header, range: 0..<100)
		writeOctal(mode, into: &header, range: 100..<108)
		writeOctal(content.count, into: &header, range: 124..<136)
		header[156] = typeFlag
		writeString(linkName, into: &header, range: 157..<257)
		data.append(contentsOf: header)
		data.append(content)
		let padding = (512 - (content.count % 512)) % 512
		if padding > 0 { data.append(Data(repeating: 0, count: padding)) }
	}

	package mutating func directory(_ name: String) {
		append(name: name, typeFlag: 0x35)
	}

	package mutating func finish() {
		data.append(Data(repeating: 0, count: 1_024))
	}

	private func writeString(_ value: String, into header: inout [UInt8], range: Range<Int>) {
		let bytes = Array(value.utf8)
		for (index, byte) in bytes.enumerated() where index < range.count {
			header[range.lowerBound + index] = byte
		}
	}

	private func writeOctal(_ value: Int, into header: inout [UInt8], range: Range<Int>) {
		let text = String(value, radix: 8)
		let bytes = Array(text.utf8)
		for (index, byte) in bytes.enumerated() where index < range.count {
			header[range.lowerBound + index] = byte
		}
	}
}
