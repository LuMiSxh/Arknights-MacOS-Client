// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension Bundle {
	var shortVersionString: String? {
		object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
	}
}

/// Builds a pre-filled GitHub bug-report URL so "Report a Problem" opens the
/// browser with version, environment, and a log excerpt already in place.
///
/// Reads log files from disk, so callers should build this lazily (e.g. inside
/// a button action), not as a `Link` destination evaluated on every view update.
enum IssueReportURL {
	static let appVersion: String = Bundle.main.shortVersionString ?? "Development"

	private static let logTailByteLimit = 1500

	static func build(problem: String? = nil) -> URL {
		var components = URLComponents(
			string: "https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/new")!
		var items = [
			URLQueryItem(name: "template", value: "bug-report.yml"),
			URLQueryItem(name: "version", value: appVersion),
			URLQueryItem(name: "environment", value: environment),
		]
		if let problem, !problem.isEmpty {
			items.append(URLQueryItem(name: "problem", value: problem))
		}
		if let logs = recentLogExcerpt() {
			items.append(URLQueryItem(name: "logs", value: logs))
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

	private static func recentLogExcerpt() -> String? {
		let paths = AppPaths()
		let sections: [(name: String, url: URL)] = [
			("launcher.log", paths.launcherLogFile),
			("wine.log", paths.logFile),
		]
		let excerpts = sections.compactMap { name, url in
			tail(of: url, maximumBytes: logTailByteLimit).map { "--- \(name) (tail) ---\n\($0)" }
		}
		guard !excerpts.isEmpty else { return nil }
		return excerpts.joined(separator: "\n\n")
			.replacingOccurrences(of: NSHomeDirectory(), with: "~")
	}

	/// Reads at most `maximumBytes` from the end of `url`, dropping a possibly
	/// truncated leading line so the excerpt starts cleanly.
	static func tail(of url: URL, maximumBytes: Int) -> String? {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
		defer { try? handle.close() }
		guard let size = try? handle.seekToEnd() else { return nil }
		let offset = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
		guard (try? handle.seek(toOffset: offset)) != nil,
			let data = try? handle.readToEnd(),
			var text = String(data: data, encoding: .utf8)
		else { return nil }
		if offset > 0, let newline = text.firstIndex(of: "\n") {
			text = String(text[text.index(after: newline)...])
		}
		return text.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
