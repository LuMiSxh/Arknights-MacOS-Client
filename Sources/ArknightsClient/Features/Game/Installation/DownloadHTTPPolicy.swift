// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Validates publisher artifact sources and their redirects before any bytes are accepted.
enum DownloadHTTPPolicy {
	private static let hostCharacters: CharacterSet = {
		var characters = CharacterSet.urlHostAllowed
		// URL.host strips the brackets from IP literals, so brackets here are malformed.
		characters.remove(charactersIn: "[]")
		return characters
	}()

	private static let gryphlineArtifactHosts: Set<String> = [
		"launcher.hg-cdn.com",
		"ak-tw.hg-cdn.com",
		"gl-utils-public.hg-cdn.com",
	]

	static func isAllowedSource(_ url: URL, for region: GameRegion) -> Bool {
		guard isValidHTTPSURL(url), let host = url.host?.lowercased() else { return false }

		switch region {
		case .global, .japan, .korea:
			return true
		case .china, .chinaBilibili:
			return url.port == nil && host.hasSuffix(".hycdn.cn")
		case .taiwan:
			return url.port == nil && gryphlineArtifactHosts.contains(host)
		}
	}

	static func redirectValidator(for region: GameRegion) -> @Sendable (URL) -> Bool {
		{ url in isAllowedSource(url, for: region) }
	}

	static func isValidHTTPSURL(_ url: URL) -> Bool {
		guard
			url.scheme?.lowercased() == "https",
			url.user == nil,
			url.password == nil,
			let host = url.host,
			!host.isEmpty
		else { return false }

		return host.unicodeScalars.allSatisfy(hostCharacters.contains)
	}
}
