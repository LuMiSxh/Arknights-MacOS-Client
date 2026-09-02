// SPDX-License-Identifier: MPL-2.0

import CCommonCrypto
import Foundation

enum HypergryphManifestCipher {
	private static let key: [UInt8] = [
		0xC0, 0xF3, 0x0E, 0x1C, 0xE7, 0x63, 0xBB, 0xC2,
		0x1C, 0xC3, 0x55, 0xA3, 0x43, 0x03, 0xAC, 0x50,
		0x39, 0x94, 0x44, 0xBF, 0xF6, 0x8C, 0x4A, 0x22,
		0xAF, 0x39, 0x8C, 0x0A, 0x16, 0x6E, 0xE1, 0x43,
	]
	private static let initializationVector: [UInt8] = [
		0x33, 0x46, 0x78, 0x61, 0x19, 0x27, 0x50, 0x64,
		0x95, 0x01, 0x93, 0x72, 0x64, 0x60, 0x84, 0x00,
	]

	static func decrypt(_ encrypted: Data) throws -> Data {
		let outputCapacity = encrypted.count + kCCBlockSizeAES128
		var output = Data(count: outputCapacity)
		var outputLength = 0
		let status = output.withUnsafeMutableBytes { outputBytes in
			encrypted.withUnsafeBytes { encryptedBytes in
				key.withUnsafeBytes { keyBytes in
					initializationVector.withUnsafeBytes { vectorBytes in
						CCCrypt(
							CCOperation(kCCDecrypt),
							CCAlgorithm(kCCAlgorithmAES),
							CCOptions(kCCOptionPKCS7Padding),
							keyBytes.baseAddress,
							key.count,
							vectorBytes.baseAddress,
							encryptedBytes.baseAddress,
							encrypted.count,
							outputBytes.baseAddress,
							outputCapacity,
							&outputLength
						)
					}
				}
			}
		}
		guard status == kCCSuccess else { throw LauncherError.invalidResponse }
		output.removeSubrange(outputLength..<output.count)
		return output
	}
}
