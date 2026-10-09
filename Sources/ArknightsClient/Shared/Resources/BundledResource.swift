// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A file or directory that the build stages into the application bundle.
///
/// This registry is the only place that names bundled resources. `scripts/lib/bundled_resources.py`
/// lists the same resources with their sources; `just check scripts` fails when the lists differ.
///
/// Documents follow one encoding rule. Files copied verbatim from the repository stay
/// `.identity`, so the bundle holds the same bytes as the source. Documents that the build
/// generates are `.deflate`.
struct BundledResource: Hashable, Sendable {
	/// The bundle that holds the resource in a packaged app and in a SwiftPM run.
	enum Origin: String, Sendable {
		/// Staged into `Contents/Resources` by `scripts/build_app.py`; read from `Bundle.main`.
		case app
		/// Declared in `Package.swift`; read from the SwiftPM resource bundle in development.
		case package
	}

	enum Kind: String, Sendable {
		case file
		case directory
	}

	/// How the staged bytes relate to the content that the app reads.
	enum Encoding: String, Sendable {
		/// The file holds the content as is.
		case identity
		/// The file holds raw deflate data, which Apple's Compression framework reads as zlib.
		case deflate
	}

	/// The path below the resource root, for example `SupportArticles/sepia.md`.
	let path: String
	let kind: Kind
	let origin: Origin
	let encoding: Encoding

	init(file path: String, origin: Origin, encoding: Encoding = .identity) {
		self.path = path
		kind = .file
		self.origin = origin
		self.encoding = encoding
	}

	init(directory path: String, origin: Origin) {
		self.path = path
		kind = .directory
		self.origin = origin
		encoding = .identity
	}

	/// A file inside this directory resource. The file keeps the directory's origin.
	func file(_ name: String, encoding: Encoding = .identity) -> BundledResource {
		precondition(kind == .directory, "Only a directory resource contains files.")
		return BundledResource(file: "\(path)/\(name)", origin: origin, encoding: encoding)
	}
}

extension BundledResource {
	static let projectLicense = BundledResource(file: "LICENSE", origin: .app)
	static let changelog = BundledResource(file: "CHANGELOG.md", origin: .app)
	static let thirdPartyNotices = BundledResource(
		file: "ThirdPartyNotices.deflate", origin: .app, encoding: .deflate)
	static let runtimeConfiguration = BundledResource(file: "RUNTIME.json", origin: .app)
	static let supportArticles = BundledResource(directory: "SupportArticles", origin: .app)
	static let compatibility = BundledResource(directory: "Compatibility", origin: .app)
	static let runtime = BundledResource(directory: "Runtime", origin: .app)

	static let wallpaperTags = BundledResource(file: "WallpaperTags.json", origin: .package)
	static let appIconTintSource = BundledResource(file: "AppIconTintSource.png", origin: .package)
	static let gameIconBackground = BundledResource(
		file: "GameIconBackground.png", origin: .package)
	static let operatorIconFrame = BundledResource(file: "OperatorIconFrame.svg", origin: .package)

	/// Every resource that the app reads by name.
	static let all: [BundledResource] = [
		.projectLicense, .changelog, .thirdPartyNotices, .runtimeConfiguration,
		.supportArticles, .compatibility, .runtime,
		.wallpaperTags, .appIconTintSource, .gameIconBackground, .operatorIconFrame,
	]
}
