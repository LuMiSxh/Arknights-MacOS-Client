// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension Bundle {
	var shortVersionString: String? {
		object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
	}
}

/// Builds a pre-filled GitHub bug-report URL with safe diagnostic metadata.
///
/// Log files are never included because they can contain private paths, URLs,
/// and account-related data. Users can review and attach logs themselves when needed.
enum IssueReportURL {
	static let appVersion: String = Bundle.main.shortVersionString ?? "Development"

	static func build(code: SupportCode? = nil, context: SupportContext? = nil) -> URL {
		var components = URLComponents(
			string: "https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/new")!
		var items = [
			URLQueryItem(name: "template", value: "bug-report.yml"),
			URLQueryItem(name: "version", value: appVersion),
			URLQueryItem(name: "environment", value: environment),
		]
		if let code {
			items.append(URLQueryItem(name: "code", value: code.rawValue))
		}
		if let context {
			items.append(URLQueryItem(name: "operation", value: context.operation.rawValue))
			if let region = context.region {
				items.append(URLQueryItem(name: "region", value: region.rawValue))
			}
		}
		components.queryItems = items
		return components.url!
	}

	private static var environment: String {
		let os = ProcessInfo.processInfo.operatingSystemVersion
		let memoryGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
		return "macOS \(os.majorVersion).\(os.minorVersion); \(chipName); \(memoryGB) GB"
	}

	private static var chipName: String {
		var size = 0
		sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
		var buffer = [CChar](repeating: 0, count: size)
		sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
		let bytes = buffer.map { UInt8(bitPattern: $0) }.prefix { $0 != 0 }
		return String(decoding: bytes, as: UTF8.self)
	}

}
