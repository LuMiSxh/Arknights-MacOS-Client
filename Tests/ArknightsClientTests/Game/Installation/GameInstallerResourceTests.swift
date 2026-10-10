// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct GameInstallerResourceTests {
	private static let childEnvironmentKey = "ARKNIGHTS_RESOURCE_TEST_CHILD"
	private static let resultPathEnvironmentKey = "ARKNIGHTS_RESOURCE_TEST_RESULT"
	private static let testFilter = "pendingDownloadsCompletesUnderLowDescriptorLimit"
	private static let fileCount = 180
	private static let descriptorLimit: rlim_t = 128

	@Test
	func pendingDownloadsCompletesUnderLowDescriptorLimit() async throws {
		if ProcessInfo.processInfo.environment[Self.childEnvironmentKey] == "1" {
			try await runDescriptorLimitedCases()
			return
		}

		try await runDescriptorLimitedChild()
	}

	private func runDescriptorLimitedCases() async throws {
		var limit = rlimit()
		guard getrlimit(RLIMIT_NOFILE, &limit) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		limit.rlim_cur = min(Self.descriptorLimit, limit.rlim_max)
		guard setrlimit(RLIMIT_NOFILE, &limit) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard getrlimit(RLIMIT_NOFILE, &limit) == 0,
			limit.rlim_cur == Self.descriptorLimit
		else {
			throw POSIXError(.EMFILE)
		}

		let cases: [(name: String, filesExist: Bool, verifyAll: Bool, pendingCount: Int)] = [
			("fresh", false, false, Self.fileCount),
			("repair", true, true, 0),
		]
		for testCase in cases {
			try await assertPendingDownloads(
				name: testCase.name,
				filesExist: testCase.filesExist,
				verifyAll: testCase.verifyAll,
				pendingCount: testCase.pendingCount
			)
		}

		guard let resultPath = ProcessInfo.processInfo.environment[Self.resultPathEnvironmentKey]
		else { throw ResourceTestError.missingResultPath }
		try Data("fresh=180\nrepair=0\n".utf8).write(
			to: URL(filePath: resultPath),
			options: .atomic
		)
	}

	private func assertPendingDownloads(
		name: String,
		filesExist: Bool,
		verifyAll: Bool,
		pendingCount: Int
	) async throws {
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appending(
			path: "GameInstallerResourceTests-\(name)-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer {
			do {
				try manager.removeItem(at: root)
			} catch {
				Issue.record("Could not remove fixture at \(root.path): \(error)")
			}
		}
		let resourceDirectory = root.appending(path: "resources", directoryHint: .isDirectory)
		try manager.createDirectory(at: resourceDirectory, withIntermediateDirectories: true)

		let body = Data([0xA5])
		var checksum = CRC64()
		checksum.update(body)
		let manifestFiles = (0..<Self.fileCount).map { index in
			ManifestFile(
				path: "resources/file-\(index).dat",
				hash: checksum.decimalString,
				size: "1"
			)
		}
		let manifest = GameManifest(source: "payload", file: manifestFiles)
		if filesExist {
			for item in manifestFiles {
				try body.write(to: root.appending(path: item.path))
			}
		}

		let baseURL = URL(string: "https://example.invalid")!
		let api = InstallerAPI(
			manifest: manifest,
			cdn: CDNConfiguration(primaryCdn: baseURL, backUpCdn: baseURL)
		)
		let installer = GameInstaller(
			api: api,
			compatibilityManager: GameCompatibilityManager()
		)
		let pending = try await withTestInstallDirectory(at: root) { installDirectory in
			try await installer.pendingDownloads(
				in: manifest,
				installDirectory: installDirectory,
				previousFiles: nil,
				verifyAllExistingFiles: verifyAll,
				progress: { _ in }
			)
		}
		guard pending.files.count == pendingCount else {
			throw ResourceTestError.unexpectedPendingCount(
				name: name,
				expected: pendingCount,
				actual: pending.files.count
			)
		}
	}

	private func runDescriptorLimitedChild() async throws {
		let manager = FileManager.default
		let resultDirectory = manager.temporaryDirectory.appending(
			path: "GameInstallerResourceTests-child-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		try manager.createDirectory(at: resultDirectory, withIntermediateDirectories: true)
		defer {
			do {
				try manager.removeItem(at: resultDirectory)
			} catch {
				Issue.record("Could not remove child files at \(resultDirectory.path): \(error)")
			}
		}
		let resultFile = resultDirectory.appending(path: "result.txt")
		let stdoutFile = resultDirectory.appending(path: "stdout.log")
		let stderrFile = resultDirectory.appending(path: "stderr.log")
		guard manager.createFile(atPath: stdoutFile.path, contents: nil),
			manager.createFile(atPath: stderrFile.path, contents: nil)
		else { throw ResourceTestError.cannotCreateChildLogs }
		let arguments = CommandLine.arguments
		guard let bundleArgument = arguments.firstIndex(of: "--test-bundle-path"),
			arguments.indices.contains(bundleArgument + 1)
		else { throw ResourceTestError.missingTestBundlePath }
		let testBundlePath = arguments[bundleArgument + 1]

		let process = Process()
		process.executableURL = URL(filePath: arguments[0])
		process.arguments = [
			"--test-bundle-path",
			testBundlePath,
			"--jobs",
			"2",
			"--filter",
			Self.testFilter,
			testBundlePath,
			"--testing-library",
			"swift-testing",
		]
		process.currentDirectoryURL = URL(filePath: manager.currentDirectoryPath)
		var environment = ProcessInfo.processInfo.environment
		environment[Self.childEnvironmentKey] = "1"
		environment[Self.resultPathEnvironmentKey] = resultFile.path
		process.environment = environment
		process.standardOutput = try FileHandle(forWritingTo: stdoutFile)
		process.standardError = try FileHandle(forWritingTo: stderrFile)
		try process.run()
		try await waitForChild(process)

		let stdout = try String(contentsOf: stdoutFile, encoding: .utf8)
		let stderr = try String(contentsOf: stderrFile, encoding: .utf8)
		guard process.terminationReason == .exit, process.terminationStatus == 0 else {
			throw ResourceTestError.childFailed(
				status: process.terminationStatus,
				output: stdout + stderr
			)
		}
		guard try String(contentsOf: resultFile, encoding: .utf8) == "fresh=180\nrepair=0\n" else {
			throw ResourceTestError.childDidNotComplete(output: stdout + stderr)
		}
	}

	private func waitForChild(_ process: Process) async throws {
		let clock = ContinuousClock()
		let deadline = clock.now.advanced(by: .seconds(60))
		do {
			while process.isRunning, clock.now < deadline {
				try await Task.sleep(for: .milliseconds(50))
			}
		} catch {
			if process.isRunning {
				_ = kill(process.processIdentifier, SIGKILL)
				process.waitUntilExit()
			}
			throw error
		}
		guard !process.isRunning else {
			process.terminate()
			let terminationDeadline = clock.now.advanced(by: .seconds(2))
			while process.isRunning, clock.now < terminationDeadline {
				try await Task.sleep(for: .milliseconds(50))
			}
			if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
			process.waitUntilExit()
			throw ResourceTestError.childTimedOut
		}
		process.waitUntilExit()
	}
}

private enum ResourceTestError: Error, CustomStringConvertible {
	case missingResultPath
	case missingTestBundlePath
	case cannotCreateChildLogs
	case unexpectedPendingCount(name: String, expected: Int, actual: Int)
	case childFailed(status: Int32, output: String)
	case childDidNotComplete(output: String)
	case childTimedOut

	var description: String {
		switch self {
		case .missingResultPath:
			"Missing child result path"
		case .missingTestBundlePath:
			"Missing SwiftPM test bundle path"
		case .cannotCreateChildLogs:
			"Could not create child test logs"
		case .unexpectedPendingCount(let name, let expected, let actual):
			"\(name) returned \(actual) pending files; expected \(expected)"
		case .childFailed(let status, let output):
			"Low-descriptor child exited with status \(status): \(output)"
		case .childDidNotComplete(let output):
			"Low-descriptor child did not run both fixture cases: \(output)"
		case .childTimedOut:
			"Low-descriptor child test timed out after 60 seconds"
		}
	}
}
