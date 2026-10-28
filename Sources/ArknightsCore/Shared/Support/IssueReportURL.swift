// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension Bundle {
	package var shortVersionString: String? {
		object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
	}
}

/// Where a report started. The raw value is the `source` answer the issue form receives.
package enum IssueReportSource: String, CaseIterable, Sendable {
	case error
	case settings
	case helpMenu = "help-menu"
	case dock
	case onboarding
}

/// Builds a pre-filled GitHub bug-report URL with safe diagnostic metadata.
///
/// Log files are never included because they can contain private paths, URLs,
/// and account-related data. Users can review and attach logs themselves when needed.
package enum IssueReportURL {
	package static let appVersion: String = Bundle.main.shortVersionString ?? "Development"

	package static func build(
		runtimeName: String?,
		code: SupportCode? = nil,
		context: SupportContext? = nil,
		source: IssueReportSource
	) -> URL {
		var components = URLComponents(
			string: "https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/new")!
		var items = [
			URLQueryItem(name: "template", value: "problem-report.yml"),
			URLQueryItem(name: "version", value: appVersion),
			URLQueryItem(name: "environment", value: environment),
		]
		if let runtimeName {
			items.append(URLQueryItem(name: "runtime", value: runtimeName))
		}
		if let code {
			items.append(URLQueryItem(name: "code", value: code.rawValue))
		}
		if let context {
			items.append(URLQueryItem(name: "operation", value: context.operation.rawValue))
			if let region = context.region {
				items.append(URLQueryItem(name: "region", value: region.rawValue))
			}
		}
		items.append(URLQueryItem(name: "source", value: source.rawValue))
		components.queryItems = items
		return components.url!
	}

	/// The macOS, chip, and memory line that a report carries. The diagnostics bundle shares it.
	package static var diagnosticsEnvironment: String { environment }

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
