// SPDX-License-Identifier: MPL-2.0

/// An error that knows which support code describes it, so lifecycle code need not name feature errors.
protocol SupportCodeProviding: Error {
	var supportCode: SupportCode? { get }
}
