// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ArknightsWordmark: View {
	let logo: NSImage?
	let cyan: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 9) {
			Group {
				if let logo {
					Image(nsImage: logo)
						.resizable()
						.scaledToFit()
				} else {
					Text("ARKNIGHTS")
						.font(.system(size: 32, weight: .regular, design: .serif))
				}
			}
			.frame(width: 245, height: 69, alignment: .leading)
			.shadow(color: .black.opacity(0.46), radius: 9, y: 3)

			HStack(spacing: 10) {
				Rectangle().fill(cyan).frame(width: 66, height: 3)
				Rectangle().fill(.white.opacity(0.34)).frame(width: 66, height: 3)
				Rectangle().fill(.white.opacity(0.16)).frame(width: 66, height: 3)
			}
		}
		.padding(.trailing, 24)
		.background {
			RadialGradient(
				colors: [.black.opacity(0.58), .black.opacity(0)],
				center: .leading,
				startRadius: 12,
				endRadius: 185
			)
			.frame(width: 320, height: 130)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Arknights Global macOS client")
	}
}

struct LauncherNoticeView: View {
	let notice: LauncherNotice
	let dismiss: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("Notice")
				.font(.title2.bold())
				.padding(.bottom, 16)
			Divider()
			ScrollView {
				Text(notice.content)
					.frame(maxWidth: .infinity, alignment: .leading)
					.textSelection(.enabled)
					.padding(.vertical, 18)
			}
			Divider()
			HStack {
				Spacer()
				Button("Done", action: dismiss)
					.keyboardShortcut(.defaultAction)
			}
			.padding(.top, 14)
		}
		.padding(24)
		.frame(width: 560, height: 380)
	}
}
