// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

private let runtimeCapabilityManifest = Data(
	#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":3,"defaultValue":3},"hardwareCursor":true}}"#
		.utf8
)

@Test
func runtimeCapabilityDiscoveryFailsClosedForMissingMalformedAndUnsafeFiles() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "runtime-capabilities-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
	defer { try? fileManager.removeItem(at: root) }

	let unconfigured = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: nil
	)
	#expect(unconfigured.capabilities == .conservative)
	#expect(unconfigured.diagnostic?.isEmpty == false)

	for unsafePath in [
		"", ".", "..", "../runtime-capabilities.json", "linked/manifest.json",
		"nested\\manifest.json", "bad\u{0}name.json",
	] {
		let discovery = RuntimeCapabilities.discover(
			inRuntimeDirectory: root,
			manifestRelativePath: unsafePath
		)
		#expect(discovery.capabilities == .conservative)
		#expect(discovery.diagnostic?.contains("single filename") == true)
	}

	let outside = fileManager.temporaryDirectory.appending(
		path: "runtime-capabilities-outside-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
	defer { try? fileManager.removeItem(at: outside) }
	try runtimeCapabilityManifest.write(to: outside.appending(path: "manifest.json"))
	try fileManager.createSymbolicLink(
		at: root.appending(path: "linked"),
		withDestinationURL: outside
	)
	let linkedParent = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: "linked/manifest.json"
	)
	#expect(linkedParent.capabilities == .conservative)
	#expect(linkedParent.diagnostic?.contains("single filename") == true)

	let relativePath = "runtime-capabilities.json"
	let manifestURL = root.appending(path: relativePath)
	try runtimeCapabilityManifest.write(to: manifestURL)
	let supported = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(
		supported.capabilities == (try RuntimeCapabilities.decode(from: runtimeCapabilityManifest)))
	#expect(supported.diagnostic == nil)

	try fileManager.removeItem(at: manifestURL)
	let missing = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(missing.capabilities == .conservative)
	#expect(missing.diagnostic?.isEmpty == false)

	try Data(
		#"{"schemaVersion":2,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":3,"defaultValue":3},"hardwareCursor":true}}"#
			.utf8
	).write(to: manifestURL)
	let malformed = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(malformed.capabilities == .conservative)
	#expect(malformed.diagnostic?.isEmpty == false)

	try fileManager.removeItem(at: manifestURL)
	try fileManager.createSymbolicLink(
		at: manifestURL,
		withDestinationURL: root.appending(path: "missing-target.json")
	)
	let symbolicLink = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(symbolicLink.capabilities == .conservative)
	#expect(symbolicLink.diagnostic?.isEmpty == false)

	try fileManager.removeItem(at: manifestURL)
	try Data(
		repeating: 97,
		count: AppConstants.Runtime.capabilityManifestMaximumBytes + 1
	).write(to: manifestURL)
	let oversized = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(oversized.capabilities == .conservative)
	#expect(oversized.diagnostic?.contains("size limit") == true)
}
