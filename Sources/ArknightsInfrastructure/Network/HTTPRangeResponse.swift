// SPDX-License-Identifier: MPL-2.0

import Foundation

package struct HTTPContentRange: Equatable, Sendable {
	package let start: Int64
	package let end: Int64
	package let total: Int64

	package var byteCount: Int64? {
		let (difference, underflow) = end.subtractingReportingOverflow(start)
		let (count, overflow) = difference.addingReportingOverflow(1)
		return underflow || overflow ? nil : count
	}

	package static func parse(_ header: String?) -> HTTPContentRange? {
		guard let header else { return nil }
		let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.lowercased().hasPrefix("bytes ") else { return nil }
		let value = trimmed.dropFirst("bytes ".count)
		let components = value.split(separator: "/", omittingEmptySubsequences: false)
		guard components.count == 2,
			let total = decimal(components[1])
		else { return nil }
		let range = components[0].split(separator: "-", omittingEmptySubsequences: false)
		guard range.count == 2,
			let start = decimal(range[0]),
			let end = decimal(range[1]),
			start <= end,
			end < total
		else { return nil }
		return HTTPContentRange(start: start, end: end, total: total)
	}

	private static func decimal(_ value: Substring) -> Int64? {
		guard !value.isEmpty, value.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
		return Int64(value)
	}
}

/// How a download response relates to the byte offset the request asked to resume from.
package enum HTTPRangeResponse: Equatable, Sendable {
	/// The body starts at byte zero. A server that ignored the range answers like this.
	case restartFromZero
	/// The body continues at the requested offset and carries `byteCount` bytes.
	case resume(HTTPContentRange, byteCount: Int64)
	case unexpectedStatus(Int)
	case invalidRange

	package static func classify(
		_ response: HTTPURLResponse,
		requestedOffset: Int64
	) -> HTTPRangeResponse {
		switch response.statusCode {
		case 200:
			return .restartFromZero
		case 206:
			guard requestedOffset > 0,
				let range = HTTPContentRange.parse(
					response.value(forHTTPHeaderField: "Content-Range")),
				range.start == requestedOffset,
				let byteCount = range.byteCount,
				response.expectedContentLength < 0 || response.expectedContentLength == byteCount
			else { return .invalidRange }
			return .resume(range, byteCount: byteCount)
		default:
			return .unexpectedStatus(response.statusCode)
		}
	}
}

package struct ByteLimitExceeded: Error, Equatable, Sendable {
	/// The size the write would have reached, or `Int64.max` when the sum overflows.
	package let attempted: Int64
}

/// Checked arithmetic for appending a chunk to a bounded download.
package enum BoundedByteCount {
	package static func adding(
		_ incoming: Int64,
		to current: Int64,
		limit: Int64
	) throws(ByteLimitExceeded) -> Int64 {
		let (total, overflow) = current.addingReportingOverflow(incoming)
		guard !overflow else { throw ByteLimitExceeded(attempted: .max) }
		guard total <= limit else { throw ByteLimitExceeded(attempted: total) }
		return total
	}
}
