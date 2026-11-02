// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import SwiftUI
import Testing

@testable import ArknightsCustomization

struct HomeLuminanceTests {
	enum Composition: Sendable {
		case darkFrame, brightFrame, darkFrameWithHighlight, brightFrameWithDarkControls
	}

	private let side = AppConstants.Theme.artworkLuminanceSampleSide

	@Test(
		arguments: [
			// A small bright block does not flip a dark frame: the median stays dark.
			(composition: Composition.darkFrameWithHighlight, expected: ColorScheme.dark),
			// The frame is bright, but the control regions are dark and weigh heavily.
			(composition: .brightFrameWithDarkControls, expected: .dark),
			(composition: .brightFrame, expected: .light),
			(composition: .darkFrame, expected: .dark),
		] as [(composition: Composition, expected: ColorScheme)])
	func compositionDecidesScheme(
		_ testCase: (composition: Composition, expected: ColorScheme)
	) throws {
		let score = try #require(
			HomeLuminance.score(pixels: makePixels(testCase.composition), side: side))
		// The previous scheme is light, so a dark result must come from the score itself.
		#expect(HomeLuminance.colorScheme(for: score, previous: .light) == testCase.expected)
	}

	@Test func fullyTransparentArtworkHasNoScore() {
		let pixels = [UInt8](repeating: 0, count: side * side * 4)
		#expect(HomeLuminance.score(pixels: pixels, side: side) == nil)
	}

	@Test(
		arguments: [
			(score: 0.62, previous: ColorScheme.dark, expected: ColorScheme.light),
			(score: 0.62, previous: .light, expected: .light),
			// Inside the band the previous decision holds in both directions.
			(score: 0.54, previous: .light, expected: .light),
			(score: 0.54, previous: .dark, expected: .dark),
			(score: 0.46, previous: .light, expected: .dark),
			(score: 0.46, previous: .dark, expected: .dark),
		] as [(score: Double, previous: ColorScheme, expected: ColorScheme)])
	func bandKeepsThePreviousSchemeAndThresholdsDecideOutside(
		_ testCase: (score: Double, previous: ColorScheme, expected: ColorScheme)
	) {
		#expect(
			HomeLuminance.colorScheme(for: testCase.score, previous: testCase.previous)
				== testCase.expected)
	}

	private func makePixels(_ composition: Composition) -> [UInt8] {
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		for row in 0..<side {
			for column in 0..<side {
				let value = shade(composition, column: column, row: row)
				let offset = (row * side + column) * 4
				pixels[offset] = value
				pixels[offset + 1] = value
				pixels[offset + 2] = value
				pixels[offset + 3] = 255
			}
		}
		return pixels
	}

	private func shade(_ composition: Composition, column: Int, row: Int) -> UInt8 {
		switch composition {
		case .darkFrame: 40
		case .brightFrame: 220
		case .darkFrameWithHighlight:
			(28..<36).contains(column) && (28..<36).contains(row) ? 255 : 40
		case .brightFrameWithDarkControls:
			isControl(column: column, row: row) ? 20 : 220
		}
	}

	// The same regions the scorer uses, so the synthetic corners sit under the Home controls.
	private func isControl(column: Int, row: Int) -> Bool {
		let center = CGPoint(
			x: (Double(column) + 0.5) / Double(side), y: (Double(row) + 0.5) / Double(side))
		return AppConstants.Theme.homeControlRegions.contains { $0.contains(center) }
	}
}
