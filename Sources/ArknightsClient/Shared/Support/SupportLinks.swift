// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Official destinations for problems outside the community launcher's responsibility.
enum SupportLinks {
	static let documentationRoot = URL(
		string: "https://lumisxh.github.io/Arknights-MacOS-Client/"
	)!
	static let yostarContact = URL(string: "https://account.yo-star.com/contact")!
	static let hypergryphContact = URL(string: "https://user.hypergryph.com/support")!
	static let donate = URL(string: "https://ko-fi.com/lumisxh")!

	static func contact(for region: GameRegion) -> URL {
		region.isChinaClient ? hypergryphContact : yostarContact
	}
}
