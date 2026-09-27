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

@Test
func bilibiliFontRegistryScriptIncludesGDIAndDirectWriteFallbacks() {
	let script = WineRuntime.registryScript(for: WineRuntime.bilibiliFontRegistryEntries())

	#expect(
		script == "Windows Registry Editor Version 5.00\r\n"
			+ "\r\n[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes]\r\n"
			+ "\"Microsoft YaHei\"=\"Hiragino Sans GB W3\"\r\n"
			+ "\"Microsoft YaHei UI\"=\"Hiragino Sans GB W3\"\r\n"
			+ "\"SimSun\"=\"Hiragino Sans GB W3\"\r\n"
			+ "\r\n[HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements]\r\n"
			+ "\"Microsoft YaHei\"=\"Hiragino Sans GB W3\"\r\n"
			+ "\"MicrosoftYaHei-Bold\"=\"Hiragino Sans GB W6\"\r\n"
			+ "\"PingFangSC-Regular\"=\"Hiragino Sans GB W3\"\r\n"
			+ "\"Noto Sans CJK SC\"=\"Hiragino Sans GB W3\"\r\n"
			+ "\"Noto Sans CJK JP\"=\"Hiragino Sans GB W3\"\r\n"
	)
}
