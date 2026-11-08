// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

@Test
func runtimeFeaturesRejectMissingFields() {
	#expect(throws: DecodingError.self) {
		try JSONDecoder().decode(
			RuntimeFeatures.self,
			from: Data(#"{"hardwareCursor":true}"#.utf8)
		)
	}
}
