// SPDX-License-Identifier: MPL-2.0

import Foundation

extension SupportCode {
	func bundledTroubleshootingMarkdown(bundle: Bundle = .main) -> String? {
		guard
			let url = bundle.url(
				forResource: rawValue.lowercased(),
				withExtension: "md",
				subdirectory: "SupportArticles"
			) ?? developmentArticleURL()
		else {
			assertionFailure("Missing bundled troubleshooting page for \(rawValue)")
			return nil
		}

		do {
			let source = try String(contentsOf: url, encoding: .utf8)
			guard let contentStart = source.range(of: "## Try this") else {
				assertionFailure("Troubleshooting page for \(rawValue) has no recovery section")
				return nil
			}
			return Self.resolveDocumentationLinks(in: String(source[contentStart.lowerBound...]))
		} catch {
			assertionFailure("Could not read troubleshooting page for \(rawValue): \(error)")
			return nil
		}
	}

	private func developmentArticleURL() -> URL? {
		#if DEBUG
			let sourceFile = URL(filePath: #filePath)
			let root = (0..<5).reduce(sourceFile) { url, _ in
				url.deletingLastPathComponent()
			}
			return root.appending(path: "docs/help/errors/\(rawValue.lowercased()).md")
		#else
			return nil
		#endif
	}

	private static func resolveDocumentationLinks(in markdown: String) -> String {
		let expression = try! NSRegularExpression(
			pattern: #"\]\(((?![A-Za-z][A-Za-z0-9+.-]*:|#)[^)]+)\)"#
		)
		let output = NSMutableString(string: markdown)
		let matches = expression.matches(
			in: markdown,
			range: NSRange(markdown.startIndex..., in: markdown)
		)
		for match in matches.reversed() {
			let target = output.substring(with: match.range(at: 1))
			guard let url = documentationURL(for: target) else { continue }
			output.replaceCharacters(in: match.range(at: 1), with: url.absoluteString)
		}
		return output as String
	}

	private static func documentationURL(for target: String) -> URL? {
		let articleRoot = SupportLinks.documentationRoot.appending(
			path: "help/errors",
			directoryHint: .isDirectory
		)
		guard let resolved = URL(string: target, relativeTo: articleRoot)?.absoluteURL.standardized,
			var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
			components.path.hasSuffix(".md")
		else {
			return nil
		}
		components.path.removeLast(3)
		components.path.append("/")
		return components.url
	}
}
