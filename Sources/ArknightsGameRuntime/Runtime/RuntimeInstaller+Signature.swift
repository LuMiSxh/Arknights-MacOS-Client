// SPDX-License-Identifier: MPL-2.0

import Foundation
import Security

extension RuntimeInstaller {
	/// The ARM runtime ships an externally signed loader bundle. Its Developer ID identity and
	/// designated requirement are part of the pin: the client verifies them and never re-signs
	/// the bundle. x86 and wrapper-added files may carry an ad-hoc signature or none.
	static let armTeamIdentifier = "QNY65H4MK6"
	static let armIdentifier = "com.riverfog7.wine"
	static let armDesignatedRequirement =
		#"identifier "com.riverfog7.wine" and anchor apple generic"#

	func verifySignatures(pin: PinnedRuntime, at runtimeRoot: URL) throws {
		guard pin.lane == .arm else { return }
		let loaderURLs = pin.interface.loaderPaths.map { runtimeRoot.appending(path: $0) }
		let existingLoader = loaderURLs.first { FileManager.default.fileExists(atPath: $0.path) }
		guard let loaderURL = existingLoader else {
			throw RuntimeInstallError.invalidInterface("the ARM interface has no loader bundle")
		}
		try verifyDeveloperID(
			url: loaderURL,
			requirement: Self.armDesignatedRequirement,
			teamIdentifier: Self.armTeamIdentifier,
			identifier: Self.armIdentifier
		)
	}

	private func verifyDeveloperID(
		url: URL,
		requirement: String,
		teamIdentifier: String,
		identifier: String
	) throws {
		var staticCode: SecStaticCode?
		guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
			let staticCode
		else {
			throw RuntimeInstallError.signatureVerificationFailed(
				"could not read the code signature at \(url.path)")
		}

		var requirementReference: SecRequirement?
		guard
			SecRequirementCreateWithString(requirement as CFString, [], &requirementReference)
				== errSecSuccess,
			let requirementReference
		else {
			throw RuntimeInstallError.signatureVerificationFailed(
				"the pinned designated requirement is invalid")
		}
		guard
			SecStaticCodeCheckValidity(
				staticCode,
				SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
				requirementReference
			) == errSecSuccess
		else {
			throw RuntimeInstallError.signatureVerificationFailed(
				"the signature does not match the pinned requirement at \(url.path)")
		}

		var information: CFDictionary?
		guard
			SecCodeCopySigningInformation(
				staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
				== errSecSuccess,
			let information
		else {
			throw RuntimeInstallError.signatureVerificationFailed(
				"could not read signing information at \(url.path)")
		}
		let values = information as NSDictionary
		guard values[kSecCodeInfoTeamIdentifier] as? String == teamIdentifier,
			values[kSecCodeInfoIdentifier] as? String == identifier
		else {
			throw RuntimeInstallError.signatureVerificationFailed(
				"the Team ID or identifier does not match the pinned values at \(url.path)")
		}
	}
}
