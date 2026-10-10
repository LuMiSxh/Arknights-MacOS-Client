// SPDX-License-Identifier: MPL-2.0

import Foundation
import OSLog

/// What one response stream has delivered so far.
struct ReceivedTransfer {
	var newlyDownloaded: Int64 = 0
	var receivedResponse = false
	var responseBodyBytes: Int64 = 0
	/// Partial length a failed range response rolls back to.
	var rangeBaseBytes: Int64
	var expectedRangeBytes: Int64?
}

/// Streams a file response into its partial, keeping the partial and the progress counter
/// consistent on every failure.
extension GameInstaller {
	/// Writes the response body to the partial and returns the bytes received from the network.
	func receive(
		_ request: URLRequest,
		redirectValidator: @escaping @Sendable (URL) -> Bool,
		into download: PartialDownload
	) async throws -> Int64 {
		let item = download.item
		let signpostID = InstallerSignposts.signposter.makeSignpostID()
		let receiveInterval = InstallerSignposts.signposter.beginInterval(
			"Receive", id: signpostID, "\(item.path)")
		defer { InstallerSignposts.signposter.endInterval("Receive", receiveInterval) }
		var firstByteInterval: OSSignpostIntervalState? =
			InstallerSignposts.signposter.beginInterval(
				"First byte", id: signpostID, "\(item.path)")
		defer {
			if let interval = firstByteInterval {
				InstallerSignposts.signposter.endInterval("First byte", interval)
			}
		}
		let stream = chunkSession.stream(for: request, redirectValidator: redirectValidator)
		defer { stream.cancel() }
		let counter = download.counter
		let report = download.progress
		let progressMonitor = Task {
			do {
				while !Task.isCancelled {
					try await Task.sleep(for: AppConstants.Network.transferRateMonitorInterval)
					guard !Task.isCancelled else { break }
					await report(await counter.refresh(file: item.path))
				}
			} catch {
				// The monitor's sleep ends when the stream completes or installation pauses.
			}
		}
		var transfer = ReceivedTransfer(rangeBaseBytes: download.existingBytes)
		do {
			try await withTaskCancellationHandler(
				operation: {
					for try await event in stream.events {
						try Task.checkCancellation()
						switch event {
						case .response(let response):
							try await acceptResponse(response, for: download, transfer: &transfer)
						case .data(let data):
							if let interval = firstByteInterval {
								InstallerSignposts.signposter.endInterval("First byte", interval)
								firstByteInterval = nil
							}
							try await write(data, from: stream, to: download, transfer: &transfer)
						}
					}
				},
				onCancel: {
					stream.cancel()
				})
		} catch {
			progressMonitor.cancel()
			await progressMonitor.value
			if Task.isCancelled { throw CancellationError() }
			if let transportError = error as? HTTPTransportError {
				throw Self.launcherError(for: transportError)
			}
			throw error
		}
		progressMonitor.cancel()
		await progressMonitor.value
		try await validateCompletedTransfer(transfer, for: download)
		return transfer.newlyDownloaded
	}

	private func acceptResponse(
		_ response: HTTPURLResponse,
		for download: PartialDownload,
		transfer: inout ReceivedTransfer
	) async throws {
		let item = download.item
		guard response.statusCode == 200 || response.statusCode == 206 else {
			throw LauncherError.invalidDownloadResponse(
				status: response.statusCode,
				path: item.path
			)
		}
		let responseMetadata = try Self.resumeMetadata(from: response, manifestHash: item.hash)
		if response.statusCode == 206 {
			try await acceptRangeResponse(
				response,
				metadata: responseMetadata,
				for: download,
				transfer: &transfer
			)
		} else {
			guard
				response.expectedContentLength < 0
					|| response.expectedContentLength == item.byteCount
			else { throw LauncherError.invalidResponse }
			if download.existingBytes > 0 {
				// The server ignored the range, so the whole file restarts from zero.
				try await download.discardBytes(counted: download.existingBytes, rewinds: true)
				download.existingBytes = 0
			}
			transfer.rangeBaseBytes = 0
			try writeResumeMetadata(responseMetadata, to: download.metadataFile)
			download.resumeMetadata = responseMetadata
		}
		transfer.receivedResponse = true
	}

	private func acceptRangeResponse(
		_ response: HTTPURLResponse,
		metadata responseMetadata: InstallerResumeMetadata,
		for download: PartialDownload,
		transfer: inout ReceivedTransfer
	) async throws {
		let item = download.item
		guard download.existingBytes > 0,
			let contentRange = InstallerContentRange.parse(
				response.value(forHTTPHeaderField: "Content-Range")
			),
			contentRange.start == download.existingBytes,
			contentRange.total == item.byteCount,
			let byteCount = contentRange.byteCount,
			response.expectedContentLength < 0
				|| response.expectedContentLength == byteCount
		else { throw LauncherError.invalidResponse }
		var acceptedMetadata = responseMetadata
		if let priorMetadata = download.resumeMetadata,
			ManifestChecksum.matches(priorMetadata.manifestHash, expected: item.hash)
		{
			if !priorMetadata.matchesEntity(responseMetadata) {
				try await download.discardBytes(counted: download.existingBytes, rewinds: true)
				download.existingBytes = 0
				try download.metadataFile.unlink()
				download.resumeMetadata = nil
				throw LauncherError.invalidResponse
			}
			acceptedMetadata = priorMetadata.preservingValidatorsOmitted(by: responseMetadata)
		}
		transfer.rangeBaseBytes = download.existingBytes
		transfer.expectedRangeBytes = byteCount
		try writeResumeMetadata(acceptedMetadata, to: download.metadataFile)
		download.resumeMetadata = acceptedMetadata
	}

	private func write(
		_ data: Data,
		from stream: HTTPChunkStream,
		to download: PartialDownload,
		transfer: inout ReceivedTransfer
	) async throws {
		let item = download.item
		guard transfer.receivedResponse else { throw LauncherError.invalidResponse }
		let accumulatedBytes = download.existingBytes + transfer.newlyDownloaded
		let incomingBytes = Int64(data.count)
		let (receivedBytes, overflow) = accumulatedBytes.addingReportingOverflow(incomingBytes)
		guard !overflow, receivedBytes <= item.byteCount else {
			try await download.discardBytes(
				counted: accumulatedBytes,
				network: transfer.newlyDownloaded
			)
			throw LauncherError.downloadedSizeMismatch(
				path: item.path,
				expected: item.byteCount,
				actual: overflow ? Int64.max : receivedBytes
			)
		}
		let (newResponseBodyBytes, responseOverflow) =
			transfer.responseBodyBytes.addingReportingOverflow(incomingBytes)
		guard !responseOverflow,
			transfer.expectedRangeBytes.map({ newResponseBodyBytes <= $0 }) ?? true
		else {
			try await discardRange(of: download, transfer: transfer)
			throw LauncherError.invalidResponse
		}
		try download.handle.write(contentsOf: data)
		stream.acknowledge(data.count)
		transfer.newlyDownloaded += incomingBytes
		transfer.responseBodyBytes = newResponseBodyBytes
		if let update = await download.counter.add(bytes: incomingBytes, file: item.path) {
			await download.progress(update)
		}
	}

	private func validateCompletedTransfer(
		_ transfer: ReceivedTransfer,
		for download: PartialDownload
	) async throws {
		guard transfer.receivedResponse else { throw LauncherError.invalidResponse }
		if let expectedRangeBytes = transfer.expectedRangeBytes,
			transfer.responseBodyBytes != expectedRangeBytes
		{
			try await discardRange(of: download, transfer: transfer, synchronizes: true)
			throw LauncherError.invalidResponse
		}
	}

	/// Keeps the bytes that existed before the range response and discards what it added.
	private func discardRange(
		of download: PartialDownload,
		transfer: ReceivedTransfer,
		synchronizes: Bool = false
	) async throws {
		try await download.discardBytes(
			truncatingTo: UInt64(transfer.rangeBaseBytes),
			counted: transfer.newlyDownloaded,
			network: transfer.newlyDownloaded,
			synchronizes: synchronizes
		)
	}
}
