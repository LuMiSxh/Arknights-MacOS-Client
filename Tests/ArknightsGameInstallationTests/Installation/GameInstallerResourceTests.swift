// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsGameInstallation

@Suite(.serialized)
struct GameInstallerResourceTests {
	private static let childEnvironmentKey = "ARKNIGHTS_RESOURCE_TEST_CHILD"
	private static let resultPathEnvironmentKey = "ARKNIGHTS_RESOURCE_TEST_RESULT"
	private static let testFilter = "pendingDownloadsCompletesUnderLowDescriptorLimit"
	private static let fileCount = 180
	private static let expectedResult = "fresh=180\nrepair=0\n"
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

		try await assertPendingDownloads(
			name: "fresh", filesExist: false, verifyAll: false, pendingCount: Self.fileCount)
		try await assertPendingDownloads(
			name: "repair", filesExist: true, verifyAll: true, pendingCount: 0)

		guard let resultPath = ProcessInfo.processInfo.environment[Self.resultPathEnvironmentKey]
		else { throw ResourceTestError.missingResultPath }
		try Data(Self.expectedResult.utf8).write(
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
		let temporary = try TemporaryDirectory("GameInstallerResourceTests-\(name)")
		defer { temporary.remove() }
		let manager = FileManager.default
		let root = temporary.url
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
		let temporary = try TemporaryDirectory("GameInstallerResourceTests-child")
		defer { temporary.remove() }
		let manager = FileManager.default
		let resultDirectory = temporary.url
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
		guard try String(contentsOf: resultFile, encoding: .utf8) == Self.expectedResult else {
			throw ResourceTestError.childDidNotComplete(output: stdout + stderr)
		}
	}

	private func waitForChild(_ process: Process) async throws {
		let deadline = ContinuousClock.now.advanced(by: .seconds(60))
		defer {
			if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
			process.waitUntilExit()
		}
		while process.isRunning {
			guard ContinuousClock.now < deadline else { throw ResourceTestError.childTimedOut }
			try await Task.sleep(for: .milliseconds(50), tolerance: .milliseconds(5))
		}
	}
}

private enum ResourceTestError: Error {
	case missingResultPath
	case missingTestBundlePath
	case cannotCreateChildLogs
	case unexpectedPendingCount(name: String, expected: Int, actual: Int)
	case childFailed(status: Int32, output: String)
	case childDidNotComplete(output: String)
	case childTimedOut
}
