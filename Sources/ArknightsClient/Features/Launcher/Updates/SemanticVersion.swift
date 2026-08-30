// SPDX-License-Identifier: MPL-2.0

/// Tolerant enough to compare both this repo's release tags and Yostar's own version
/// strings, including an optional leading "v" and dot-separated prerelease identifiers.
struct SemanticVersion: Comparable {
	private enum PrereleaseIdentifier: Comparable {
		case numeric(Int)
		case text(String)

		static func < (lhs: Self, rhs: Self) -> Bool {
			switch (lhs, rhs) {
			case (.numeric(let left), .numeric(let right)):
				left < right
			case (.numeric, .text):
				true
			case (.text, .numeric):
				false
			case (.text(let left), .text(let right)):
				left < right
			}
		}
	}

	let major: Int
	let minor: Int
	let patch: Int
	private let prerelease: [PrereleaseIdentifier]?

	init?(_ input: String) {
		let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
		let withoutPrefix =
			trimmed.first?.lowercased() == "v" ? String(trimmed.dropFirst()) : trimmed
		let buildComponents = withoutPrefix.split(
			separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
		guard buildComponents.count <= 2 else { return nil }
		if buildComponents.count == 2 {
			let identifiers = buildComponents[1].split(
				separator: ".", omittingEmptySubsequences: false)
			guard !identifiers.isEmpty, identifiers.allSatisfy(Self.isValidIdentifier) else {
				return nil
			}
		}

		let components = buildComponents[0].split(
			separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
		let core = components[0].split(separator: ".", omittingEmptySubsequences: false)

		guard (1...3).contains(core.count), core.allSatisfy({ Self.isValidCoreNumber($0) }) else {
			return nil
		}

		guard let major = Int(core[0]),
			let minor = core.count > 1 ? Int(core[1]) : 0,
			let patch = core.count > 2 ? Int(core[2]) : 0
		else {
			return nil
		}

		self.major = major
		self.minor = minor
		self.patch = patch

		if components.count == 2 {
			let identifiers = components[1].split(separator: ".", omittingEmptySubsequences: false)
			guard !identifiers.isEmpty, identifiers.allSatisfy(Self.isValidPrereleaseIdentifier)
			else {
				return nil
			}
			var parsedIdentifiers = [PrereleaseIdentifier]()
			for identifier in identifiers {
				if identifier.allSatisfy(\.isNumber) {
					guard let number = Int(identifier) else { return nil }
					parsedIdentifiers.append(.numeric(number))
				} else {
					parsedIdentifiers.append(.text(String(identifier)))
				}
			}
			prerelease = parsedIdentifiers
		} else {
			prerelease = nil
		}
	}

	static func < (lhs: Self, rhs: Self) -> Bool {
		if lhs.major != rhs.major { return lhs.major < rhs.major }
		if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
		if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

		switch (lhs.prerelease, rhs.prerelease) {
		case (nil, nil):
			return false
		case (nil, .some):
			return false
		case (.some, nil):
			return true
		case (.some(let left), .some(let right)):
			for (leftIdentifier, rightIdentifier) in zip(left, right) {
				if leftIdentifier != rightIdentifier {
					return leftIdentifier < rightIdentifier
				}
			}
			return left.count < right.count
		}
	}

	private static func isValidCoreNumber(_ value: Substring) -> Bool {
		guard !value.isEmpty, value.allSatisfy(\.isNumber) else { return false }
		return value.count == 1 || value.first != "0"
	}

	private static func isValidPrereleaseIdentifier(_ value: Substring) -> Bool {
		guard isValidIdentifier(value) else { return false }
		return !value.allSatisfy(\.isNumber) || value.count == 1 || value.first != "0"
	}

	private static func isValidIdentifier(_ value: Substring) -> Bool {
		!value.isEmpty
			&& value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
	}
}
