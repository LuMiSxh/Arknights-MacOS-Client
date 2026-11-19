// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Redirect validators shared by the HTTP loaders.
package enum HTTPRedirectPolicy {
	/// Rejects any redirect that leaves HTTPS, so a download cannot be downgraded.
	package static let httpsOnly: @Sendable (URL) -> Bool = {
		$0.scheme?.lowercased() == "https"
	}
}
