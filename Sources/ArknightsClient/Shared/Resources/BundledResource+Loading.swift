// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The reason a bundled resource could not be loaded. Callers map it at their feature boundary.
enum BundledResourceError: Error, Equatable, LocalizedError, Sendable {
	/// The bundle does not contain the resource.
	case missing(path: String)
	/// The resource exists but the file system could not read it.
	case unreadable(path: String, reason: String)
	/// The resource was read but its content is not valid: bad deflate data, bad UTF-8, or bad JSON.
	case corrupt(path: String, reason: String)

	var errorDescription: String? {
		switch self {
		case .missing(let path):
			"The bundled resource \(path) is missing."
		case .unreadable(let path, let reason):
			"The bundled resource \(path) could not be read: \(reason)"
		case .corrupt(let path, let reason):
			"The bundled resource \(path) is corrupt: \(reason)"
		}
	}
}

extension BundledResource.Origin {
	var bundle: Bundle {
		switch self {
		case .app: .main
		case .package: AppResourceBundle.bundle
		}
	}
}

extension BundledResource {
	/// The location of the resource below a resource root. It does not check existence.
	func location(in resources: URL) -> URL {
		resources.appending(
			path: path, directoryHint: kind == .directory ? .isDirectory : .notDirectory)
	}

	/// The location of the resource in a bundle. Pass `bundle` to override the resource's origin.
	///
	/// - Throws: `BundledResourceError.missing` when the bundle has no such file or directory.
	func url(in bundle: Bundle? = nil) throws -> URL {
		let bundle = bundle ?? origin.bundle
		let components = path as NSString
		let directory = components.deletingLastPathComponent
		let name = (components.lastPathComponent as NSString).deletingPathExtension
		let fileExtension = (components.lastPathComponent as NSString).pathExtension
		let found =
			switch kind {
			case .file:
				bundle.url(
					forResource: name,
					withExtension: fileExtension.isEmpty ? nil : fileExtension,
					subdirectory: directory.isEmpty ? nil : directory
				)
			case .directory:
				bundle.resourceURL.map { location(in: $0) }.flatMap {
					FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
				}
			}
		guard let found else { throw BundledResourceError.missing(path: path) }
		return found
	}

	/// The file content, inflated when the encoding is `.deflate`.
	func data(in bundle: Bundle? = nil) throws -> Data {
		precondition(kind == .file, "Only a file resource has data.")
		let url = try url(in: bundle)
		let stored: Data
		do {
			stored = try Data(contentsOf: url)
		} catch {
			throw BundledResourceError.unreadable(path: path, reason: error.localizedDescription)
		}
		switch encoding {
		case .identity:
			return stored
		case .deflate:
			do {
				return try (stored as NSData).decompressed(using: .zlib) as Data
			} catch {
				throw BundledResourceError.corrupt(path: path, reason: error.localizedDescription)
			}
		}
	}

	/// The file content as strict UTF-8 text.
	func text(in bundle: Bundle? = nil) throws -> String {
		let data = try data(in: bundle)
		guard let text = String(data: data, encoding: .utf8) else {
			throw BundledResourceError.corrupt(
				path: path, reason: "The content is not valid UTF-8.")
		}
		return text
	}

	/// The file content decoded from JSON.
	func decode<Value: Decodable>(
		_ type: Value.Type = Value.self,
		using decoder: JSONDecoder = JSONDecoder(),
		in bundle: Bundle? = nil
	) throws -> Value {
		let data = try data(in: bundle)
		do {
			return try decoder.decode(type, from: data)
		} catch {
			throw BundledResourceError.corrupt(path: path, reason: String(describing: error))
		}
	}
}
