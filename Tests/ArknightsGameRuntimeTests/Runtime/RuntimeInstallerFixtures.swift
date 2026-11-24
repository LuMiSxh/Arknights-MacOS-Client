// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import CryptoKit
import Foundation

@testable import ArknightsGameRuntime

func sha256Hex(_ data: Data) -> String {
	SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func makePin(
	archive: Data,
	sha256: String? = nil,
	version: String = "1.0.0",
	name: String = "Test Runtime",
	deltas: [PinnedRuntimeDelta] = []
) -> PinnedRuntime {
	PinnedRuntime(
		lane: .x86,
		name: name,
		version: version,
		url: URL(string: "https://download.test/runtime.tar.xz"),
		sha256: sha256 ?? sha256Hex(archive),
		sizeBytes: archive.count,
		minimumMacOS: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0),
		prefixRevision: 2,
		interface: RuntimeManifest.Interface(
			executables: ["bin/wine64", "bin/wineserver"],
			features: RuntimeFeatures(
				hardwareCursor: true,
				metalFXSpatialUpscaling: false,
				nativeFullscreenSpace: false
			),
			requiredFiles: [
				"lib/wine/x86_64-unix/winemac.so",
				"lib/wine/x86_64-unix/winecoreaudio.so",
				"lib/wine/x86_64-windows/winemetal.dll",
			],
			macDriver: "lib/wine/x86_64-unix/winemac.so",
			launcher: .init(path: "bin/Arknights", target: "wine64"),
			dxmt: .init(
				payloadDirectory: "DXMT",
				destinations: ["x64": "system32"],
				libraries: ["d3d11.dll"]
			)
		),
		components: RuntimeManifest.Components(wine: "11.17", dxmt: "0.80", moltenvk: nil),
		provenance: nil,
		deltas: deltas
	)
}

func makeInstallerPaths(_ temporary: TemporaryDirectory) -> AppPaths {
	AppPaths(
		applicationSupportDirectory: temporary.url,
		runtimeSelection: RuntimeSelection(override: .x86)
	)
}

func makeInstaller(
	paths: AppPaths,
	route: StubURLProtocol.Route,
	clock: any Clock<Duration> = ContinuousClock()
) -> RuntimeInstaller {
	RuntimeInstaller(
		paths: paths,
		selectionStore: RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile),
		access: RuntimeAccess(
			macOSVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
		),
		session: route.session,
		clock: clock
	)
}
