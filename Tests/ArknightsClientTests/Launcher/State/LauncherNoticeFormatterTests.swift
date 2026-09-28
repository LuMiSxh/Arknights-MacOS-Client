// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func noticeHTMLDropsElementsThatLoadRemoteResources() {
	let html = """
		<p style="background: url('https://tracker.test/a.png')">Maintenance <b>tonight</b></p>
		<img src="https://tracker.test/b.png"><script>alert(1)</script>
		<link rel="stylesheet" href="https://tracker.test/c.css">
		<a href="https://yostar.test/news">Details</a>
		"""

	let sanitized = LauncherNoticeFormatter.withoutRemoteResources(html)

	#expect(!sanitized.contains("tracker.test"))
	#expect(!sanitized.contains("alert"))
	#expect(sanitized.contains("<b>tonight</b>"))
	#expect(sanitized.contains(#"<a href="https://yostar.test/news">Details</a>"#))
}
