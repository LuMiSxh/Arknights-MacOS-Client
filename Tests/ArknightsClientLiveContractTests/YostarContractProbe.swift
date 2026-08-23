// SPDX-License-Identifier: MPL-2.0

import Foundation

@testable import ArknightsClient

struct YostarContractProbe {
	private static let attempts = 3
	private static let retryDelay: Duration = .seconds(2)

	private let api: LauncherAPI
	private let installer: GameInstaller

	init() {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.timeoutIntervalForRequest = 15
		configuration.timeoutIntervalForResource = 30
		let api = LauncherAPI(session: URLSession(configuration: configuration))
		self.api = api
		installer = GameInstaller(
			api: api,
			compatibilityManager: GameCompatibilityManager(active: [])
		)
	}

	func run(environment: [String: String]) async -> LiveContractReport {
		var checks: [LiveContractCheck] = []
		for region in GameRegion.allCases {
			checks.append(await brandingCheck(region))
			let configuration = await configurationCheck(region)
			checks.append(configuration.check)
			checks.append(await cdnCheck(region))

			guard let gameConfiguration = configuration.value else {
				checks.append(blocked(region, "manifest-location", by: "game-configuration"))
				checks.append(blocked(region, "manifest", by: "game-configuration"))
				continue
			}

			let location = await manifestLocationCheck(region, gameConfiguration)
			checks.append(location.check)
			guard let manifestLocation = location.value else {
				checks.append(blocked(region, "manifest", by: "manifest-location"))
				continue
			}
			checks.append(await manifestCheck(region, manifestLocation))
		}
		return LiveContractReport(checks: checks, environment: environment)
	}

	private func brandingCheck(_ region: GameRegion) async -> LiveContractCheck {
		await check(region, "branding") {
			let branding = try await api.branding(region: region)
			for url in [
				branding.launcherBackgroundImage,
				branding.privacyPolicy,
				branding.userAgreement,
			].compactMap({ $0 }) {
				try Self.validateHTTPS(url, expectedHosts: Self.brandingHosts(for: region))
			}
			return "decoded"
		}.check
	}

	private func configurationCheck(
		_ region: GameRegion
	) async -> ProbeResult<GameConfiguration> {
		await check(region, "game-configuration") {
			let configuration = try await api.gameConfiguration(region: region)
			guard !configuration.gameLatestVersion.isEmpty else {
				throw ProbeError.invalid("missing latest version")
			}
			guard !configuration.executableName.isEmpty else {
				throw ProbeError.invalid("missing executable name")
			}
			_ = try GameInstaller.safeRelativePath(configuration.gameLatestFilePath)
			return (configuration, "version \(configuration.gameLatestVersion)")
		}
	}

	private func cdnCheck(_ region: GameRegion) async -> LiveContractCheck {
		await check(region, "cdn") {
			let configuration = try await api.cdnConfiguration(region: region)
			let expectedHosts = Self.downloadHosts(for: region)
			try Self.validateHTTPS(configuration.primaryCdn, expectedHosts: expectedHosts)
			try Self.validateHTTPS(configuration.backUpCdn, expectedHosts: expectedHosts)
			return "primary and backup available"
		}.check
	}

	private func manifestLocationCheck(
		_ region: GameRegion,
		_ configuration: GameConfiguration
	) async -> ProbeResult<ManifestLocation> {
		await check(region, "manifest-location") {
			let location = try await api.manifestLocation(for: configuration, region: region)
			try Self.validateHTTPS(
				location.url,
				expectedHosts: Self.downloadHosts(for: region)
			)
			return (location, "HTTPS location available")
		}
	}

	private func manifestCheck(
		_ region: GameRegion,
		_ location: ManifestLocation
	) async -> LiveContractCheck {
		await check(region, "manifest") {
			let payload = try await api.manifestPayload(at: location.url, region: region)
			guard !payload.manifest.file.isEmpty else {
				throw ProbeError.invalid("manifest contains no files")
			}
			let root = FileManager.default.temporaryDirectory.appending(
				path: "ArknightsContractValidation-\(region.rawValue)-\(UUID().uuidString)"
			)
			try installer.validateManifest(payload.manifest, inside: root)
			for file in payload.manifest.file {
				guard UInt64(file.hash) != nil else {
					throw ProbeError.invalid("manifest contains an invalid checksum")
				}
				guard let size = Int64(file.size), size >= 0 else {
					throw ProbeError.invalid("manifest contains an invalid file size")
				}
			}
			return "\(payload.manifest.file.count) files, \(payload.byteCount) bytes"
		}.check
	}

	private func check(
		_ region: GameRegion,
		_ contract: String,
		operation: @escaping () async throws -> String
	) async -> ProbeResult<Void> {
		await check(region, contract) { ((), try await operation()) }
	}

	private func check<Value: Sendable>(
		_ region: GameRegion,
		_ contract: String,
		operation: @escaping () async throws -> (Value, String)
	) async -> ProbeResult<Value> {
		var lastError: (any Error)?
		for attempt in 1...Self.attempts {
			do {
				let (value, summary) = try await operation()
				return ProbeResult(
					check: LiveContractCheck(
						region: region.rawValue,
						contract: contract,
						status: .healthy,
						summary: Self.sanitize(summary)
					),
					value: value
				)
			} catch {
				lastError = error
				if error is ProbeError
					|| launcherDiagnosticDescription(for: error).contains("decoding failed")
				{
					break
				}
				if attempt < Self.attempts {
					try? await Task.sleep(for: Self.retryDelay)
				}
			}
		}
		return ProbeResult(
			check: LiveContractCheck(
				region: region.rawValue,
				contract: contract,
				status: .failed,
				summary: Self.failureSummary(lastError)
			),
			value: nil
		)
	}

	private func blocked(_ region: GameRegion, _ contract: String, by dependency: String)
		-> LiveContractCheck
	{
		LiveContractCheck(
			region: region.rawValue,
			contract: contract,
			status: .blocked,
			summary: "blocked by \(dependency)"
		)
	}

	private static func validateHTTPS(_ url: URL, expectedHosts: Set<String>) throws {
		guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else {
			throw ProbeError.invalid("URL is not a credential-free HTTPS endpoint")
		}
		guard let host = url.host?.lowercased(), expectedHosts.contains(host) else {
			throw ProbeError.invalid("URL uses an unexpected host")
		}
	}

	private static func brandingHosts(for region: GameRegion) -> Set<String> {
		let websiteHosts: Set<String> =
			switch region {
			case .global: ["www.arknights.global"]
			case .japan: ["arknights.jp", "www.arknights.jp"]
			case .korea: ["arknights.kr", "www.arknights.kr"]
			}
		return websiteHosts.union(downloadHosts(for: region))
	}

	private static func downloadHosts(for region: GameRegion) -> Set<String> {
		switch region {
		case .global:
			["launcher-pkg-ark-en.yo-star.com", "launcher-pkg-ark-en-bk.yo-star.com"]
		case .japan:
			["launcher-pkg-ark-jp.yo-star.com", "launcher-pkg-ark-jp-bk.yo-star.com"]
		case .korea:
			["launcher-pkg-ark-kr.yo-star.com", "launcher-pkg-ark-kr-bk.yo-star.com"]
		}
	}

	private static func failureSummary(_ error: (any Error)?) -> String {
		guard let error else { return "unknown failure" }
		if let probeError = error as? ProbeError {
			return sanitize(probeError.description)
		}
		let diagnostic = launcherDiagnosticDescription(for: error)
		if diagnostic.contains("decoding failed") { return "response decoding failed" }
		if diagnostic.contains("response exceeded") { return "response exceeds size limit" }
		if diagnostic.contains("transport error") { return "transport error" }
		if let status = diagnostic.range(of: "status=") {
			let value = diagnostic[status.upperBound...].prefix(while: \.isNumber)
			return "HTTP \(value)"
		}
		return "unexpected contract failure"
	}

	private static func sanitize(_ value: String) -> String {
		let singleLine = value.replacingOccurrences(of: "\n", with: " ")
			.replacingOccurrences(of: "\r", with: " ")
		return String(singleLine.prefix(240))
	}
}

private struct ProbeResult<Value: Sendable>: Sendable {
	let check: LiveContractCheck
	let value: Value?
}

private enum ProbeError: Error, CustomStringConvertible {
	case invalid(String)

	var description: String {
		switch self {
		case .invalid(let message): message
		}
	}
}
