// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func registryScriptGroupsEntriesUnderExpandedRootKeys() {
	let script = WineRuntime.registryScript(for: [
		WineRegistryEntry(
			key: "HKCU\\Software\\Wine\\DllOverrides",
			name: "d3d11",
			kind: .string("native,builtin")
		),
		WineRegistryEntry(
			key: "HKCU\\Software\\Wine\\WineDbg",
			name: "ShowCrashDialog",
			kind: .dword(0)
		),
		WineRegistryEntry(
			key: "HKCU\\Software\\Wine\\DllOverrides",
			name: "dcomp",
			kind: .string("")
		),
	])

	#expect(
		script == "Windows Registry Editor Version 5.00\r\n"
			+ "\r\n[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]\r\n"
			+ "\"d3d11\"=\"native,builtin\"\r\n"
			+ "\"dcomp\"=\"\"\r\n"
			+ "\r\n[HKEY_CURRENT_USER\\Software\\Wine\\WineDbg]\r\n"
			+ "\"ShowCrashDialog\"=dword:00000000\r\n"
	)
}

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
