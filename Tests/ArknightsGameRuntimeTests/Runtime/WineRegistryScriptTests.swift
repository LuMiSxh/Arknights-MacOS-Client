// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsGameRuntime

@Test
func registryScriptEscapesBackslashesAndQuotesInValues() {
	let script = WineRuntime.registryScript(for: [
		WineRegistryEntry(
			key: "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes",
			name: "Microsoft YaHei",
			kind: .string("C:\\fonts\\\"Hiragino Sans GB W3\"")
		)
	])

	#expect(
		script.contains(
			"[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes]"
		)
	)
	#expect(script.contains("\"Microsoft YaHei\"=\"C:\\\\fonts\\\\\\\"Hiragino Sans GB W3\\\"\""))
}
