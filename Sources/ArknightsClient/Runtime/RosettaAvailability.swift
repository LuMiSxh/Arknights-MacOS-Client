// SPDX-License-Identifier: MPL-2.0

import Foundation

struct IntelTranslationCheck: Equatable, Sendable {
	let state: IntelTranslationState
	let diagnostics: String
}

struct IntelTranslationProcessResult: Equatable, Sendable {
	let status: Int32
	let output: String
}

/// Verifies that macOS can execute an Intel process instead of trusting Rosetta's on-disk
/// marker alone. macOS 27 can retain that marker while its beta-only game test mode disables
/// general Rosetta translation, and an OS upgrade can remove Rosetta without surfacing the
/// normal installer prompt to a command-line Wine child process.
enum RosettaAvailability {
	private static let runtimePath = "/Library/Apple/usr/share/rosetta/rosetta"
	private static let architectureTool = URL(filePath: "/usr/bin/arch")
	private static let noOpTool = "/usr/bin/true"
	private static let gameTestTool = URL(filePath: "/usr/bin/game-test-tool")

	static func check(
		operatingSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo
			.operatingSystemVersion,
		operatingSystemVersionString: String = ProcessInfo.processInfo
			.operatingSystemVersionString,
		fileManager: FileManager = .default,
		rosettaRuntimePresent: Bool? = nil,
		gameTestToolAvailable: Bool? = nil,
		runProcess:
			@escaping @Sendable (URL, [String]) async throws
			-> IntelTranslationProcessResult = run
	) async -> IntelTranslationCheck {
		let majorVersion = operatingSystemVersion.majorVersion
		guard majorVersion < 28 else {
			return IntelTranslationCheck(
				state: .unsupportedOS,
				diagnostics: "os=\(operatingSystemVersionString) generalRosettaUnsupported=true"
			)
		}

		var diagnosticParts = ["os=\(operatingSystemVersionString)"]
		let canInspectGameTestMode =
			gameTestToolAvailable ?? fileManager.isExecutableFile(atPath: gameTestTool.path)
		if majorVersion >= 27, canInspectGameTestMode {
			do {
				let result = try await runProcess(gameTestTool, ["status"])
				let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
				diagnosticParts.append(
					"gameTestStatus=\(result.status) output=\(output.isEmpty ? "empty" : output)"
				)
				if result.status == 0, gameTestModeIsEnabled(output) {
					return IntelTranslationCheck(
						state: .gameTestModeEnabled,
						diagnostics: diagnosticParts.joined(separator: " ")
					)
				}
			} catch {
				diagnosticParts.append("gameTestStatusError=\(error.localizedDescription)")
			}
		} else {
			diagnosticParts.append("gameTestTool=unavailable")
		}

		let runtimePresent =
			rosettaRuntimePresent ?? fileManager.fileExists(atPath: runtimePath)
		diagnosticParts.append("runtimeMarker=\(runtimePresent)")
		guard runtimePresent else {
			return IntelTranslationCheck(
				state: .rosettaMissing,
				diagnostics: diagnosticParts.joined(separator: " ")
			)
		}

		do {
			let result = try await runProcess(
				architectureTool,
				["-x86_64", noOpTool]
			)
			diagnosticParts.append("intelProbeStatus=\(result.status)")
			return IntelTranslationCheck(
				state: result.status == 0 ? .available : .unavailable,
				diagnostics: diagnosticParts.joined(separator: " ")
			)
		} catch {
			diagnosticParts.append(
				"intelProbeError=\(isBadCPUType(error) ? "EBADARCH" : error.localizedDescription)"
			)
			return IntelTranslationCheck(
				state: .unavailable,
				diagnostics: diagnosticParts.joined(separator: " ")
			)
		}
	}

	static func gameTestModeIsEnabled(_ output: String) -> Bool {
		let normalized = output.lowercased()
		guard normalized.contains("enabled") else { return false }
		return !normalized.contains("disabled") && !normalized.contains("not enabled")
	}

	static func isBadCPUType(_ error: Error) -> Bool {
		let nsError = error as NSError
		if nsError.domain == NSPOSIXErrorDomain
			&& nsError.code == Int(POSIXErrorCode.EBADARCH.rawValue)
		{
			return true
		}
		guard let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error else {
			return false
		}
		return isBadCPUType(underlying)
	}

	private static func run(
		executable: URL,
		arguments: [String]
	) async throws -> IntelTranslationProcessResult {
		try await withCheckedThrowingContinuation { continuation in
			let process = Process()
			let output = Pipe()
			process.executableURL = executable
			process.arguments = arguments
			process.standardOutput = output
			process.standardError = output
			process.terminationHandler = { process in
				let data = output.fileHandleForReading.readDataToEndOfFile()
				continuation.resume(
					returning: IntelTranslationProcessResult(
						status: process.terminationStatus,
						output: String(decoding: data, as: UTF8.self)
					)
				)
			}
			do {
				try process.run()
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
}
