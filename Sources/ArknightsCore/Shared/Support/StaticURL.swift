// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Builds URLs from strings the app ships. A malformed value is a programmer error, so it stops.
enum StaticURL {
	static func url(_ string: String) -> URL {
		guard let url = URL(string: string) else {
			preconditionFailure("Invalid static URL: \(string)")
		}
		return url
	}

	static func components(_ string: String) -> URLComponents {
		guard let components = URLComponents(string: string) else {
			preconditionFailure("Invalid static URL components: \(string)")
		}
		return components
	}

	static func url(_ components: URLComponents) -> URL {
		guard let url = components.url else {
			preconditionFailure(
				"Invalid URL components: \(components.string ?? "unprintable")")
		}
		return url
	}
}
