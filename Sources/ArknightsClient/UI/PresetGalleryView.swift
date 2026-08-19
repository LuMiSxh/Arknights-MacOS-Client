// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct PresetGalleryView: View {
	var model: LauncherViewModel
	@Binding var initialTab: PresetGalleryTab
	@Environment(\.dismiss) private var dismiss

	@State private var selectedTab: PresetGalleryTab = .avatars
	@State private var searchText = ""
	@State private var avatars: [PresetAvatar] = []
	@State private var wallpapers: [PresetWallpaper] = []
	@State private var isLoadingAvatars = true
	@State private var isLoadingWallpapers = true
	@State private var applyingItemID: String?

	private let avatarColumns = [
		GridItem(.adaptive(minimum: 88, maximum: 105), spacing: 14)
	]
	private let wallpaperColumns = [
		GridItem(.flexible(), spacing: 14),
		GridItem(.flexible(), spacing: 14),
		GridItem(.flexible(), spacing: 14),
	]

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			VStack(spacing: 0) {
				header
				Divider().overlay(Color.white.opacity(0.08))

				searchAndFilterBar
					.padding(.horizontal, 24)
					.padding(.vertical, 14)

				ScrollView {
					Group {
						if selectedTab == .avatars {
							if isLoadingAvatars && avatars.isEmpty {
								loadingState(text: "Loading operators…")
							} else {
								avatarsGrid
							}
						} else {
							if isLoadingWallpapers && wallpapers.isEmpty {
								loadingState(text: "Loading official wallpapers…")
							} else {
								wallpapersGrid
							}
						}
					}
					.padding(.horizontal, 24)
					.padding(.bottom, 64)
				}
				.contentMargins(.top, 8, for: .scrollIndicators)
				.contentMargins(.bottom, 24, for: .scrollIndicators)
			}

			// Soft bottom gradient scrim
			LinearGradient(
				colors: [.clear, Color.black.opacity(0.45)],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: 56)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
			.allowsHitTesting(false)

			// Floating Done capsule button with shadow
			Button {
				dismiss()
			} label: {
				Text("Done")
					.fontWeight(.semibold)
					.foregroundStyle(model.accentTextColor)
					.padding(.horizontal, 10)
					.padding(.vertical, 2)
			}
			.adaptiveGlassButton(prominent: true)
			.buttonBorderShape(.capsule)
			.tint(model.accentColor)
			.shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 4)
			.padding(.trailing, 24)
			.padding(.bottom, 18)
			.keyboardShortcut(.defaultAction)
		}
		.frame(width: 720, height: 540)
		.background(
			ZStack {
				Color(red: 0.07, green: 0.07, blue: 0.08)
				model.hudTintColor
			}
		)
		.preferredColorScheme(.dark)
		.onAppear {
			selectedTab = initialTab
			Task {
				avatars = await PresetCatalogService.shared.fetchAvatars()
				isLoadingAvatars = false
			}
			Task {
				wallpapers = await PresetCatalogService.shared.fetchWallpapers()
				isLoadingWallpapers = false
			}
		}
	}

	private var header: some View {
		HStack {
			Text("Asset Gallery")
				.font(.title3.bold())
			Spacer()
		}
		.padding(.horizontal, 24)
		.padding(.vertical, 16)
	}

	private var searchAndFilterBar: some View {
		HStack(spacing: 14) {
			Picker("Category", selection: $selectedTab) {
				ForEach(PresetGalleryTab.allCases) { tab in
					Label(tab.rawValue, systemImage: tab.icon).tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.frame(width: 320)

			HStack {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(.tertiary)
				TextField("Search…", text: $searchText)
					.textFieldStyle(.plain)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(Color.white.opacity(0.06), in: Capsule())
		}
	}

	private var filteredAvatars: [PresetAvatar] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if query.isEmpty { return avatars }
		return avatars.filter { $0.name.lowercased().contains(query) }
	}

	private var filteredWallpapers: [PresetWallpaper] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if query.isEmpty { return wallpapers }
		return wallpapers.filter { $0.title.lowercased().contains(query) }
	}

	private func loadingState(text: String) -> some View {
		VStack(spacing: 12) {
			ProgressView().controlSize(.regular)
			Text(text)
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, minHeight: 240)
	}

	private var avatarsGrid: some View {
		LazyVGrid(columns: avatarColumns, spacing: 16) {
			ForEach(filteredAvatars) { avatar in
				let isApplying = applyingItemID == avatar.id
				Button {
					applyAvatar(avatar)
				} label: {
					VStack(spacing: 6) {
						ZStack {
							CachedPresetImage(
								url: avatar.url,
								cacheKey: avatar.id,
								contentMode: .fill,
								placeholderIcon: "person.crop.square.fill"
							)
							.frame(width: 76, height: 76)
							.background(
								LinearGradient(
									colors: [
										Color(red: 0.16, green: 0.17, blue: 0.19),
										Color(red: 0.06, green: 0.06, blue: 0.07),
									],
									startPoint: .top,
									endPoint: .bottom
								)
							)
							.clipShape(RoundedRectangle(cornerRadius: 17))

							// Applying spinner overlay
							if isApplying {
								ZStack {
									Color.black.opacity(0.65)
									ProgressView()
										.controlSize(.small)
										.tint(model.accentColor)
								}
								.clipShape(RoundedRectangle(cornerRadius: 17))
							}
						}
						.frame(width: 76, height: 76)
						.overlay {
							RoundedRectangle(cornerRadius: 17)
								.strokeBorder(
									isApplying ? model.accentColor : Color.white.opacity(0.14),
									lineWidth: isApplying ? 2.5 : 1.5
								)
						}
						.shadow(
							color: isApplying
								? model.accentColor.opacity(0.5) : Color.black.opacity(0.4),
							radius: isApplying ? 8 : 5,
							x: 0,
							y: 3
						)

						Text(avatar.name)
							.font(.system(size: 11, weight: isApplying ? .bold : .medium))
							.lineLimit(1)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? model.accentColor : .primary)
							.frame(maxWidth: 88)
					}
					.padding(.vertical, 4)
					.frame(maxWidth: .infinity)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.disabled(applyingItemID != nil)
			}
		}
	}

	private var wallpapersGrid: some View {
		LazyVGrid(columns: wallpaperColumns, spacing: 14) {
			ForEach(filteredWallpapers) { wp in
				let isApplying = applyingItemID == wp.id
				Button {
					applyWallpaper(wp)
				} label: {
					VStack(alignment: .leading, spacing: 6) {
						ZStack {
							CachedPresetImage(
								url: wp.thumbnailURL ?? wp.url,
								cacheKey: "thumb_\(wp.id)",
								contentMode: .fill,
								placeholderIcon: "photo"
							)
							.frame(minWidth: 0, maxWidth: .infinity)
							.frame(height: 105)
							.clipped()
							.clipShape(RoundedRectangle(cornerRadius: 10))

							// Applying spinner overlay
							if isApplying {
								ZStack {
									Color.black.opacity(0.68)
									VStack(spacing: 6) {
										ProgressView()
											.controlSize(.regular)
											.tint(model.accentColor)
										Text("Applying…")
											.font(.caption2.bold())
											.foregroundStyle(.white)
									}
								}
								.clipShape(RoundedRectangle(cornerRadius: 10))
							}
						}
						.frame(height: 105)
						.background(Color.white.opacity(0.05), in: .rect(cornerRadius: 10))

						Text(wp.title)
							.font(.caption.weight(isApplying ? .bold : .medium))
							.lineLimit(1)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? model.accentColor : .primary)
					}
					.padding(8)
					.frame(maxWidth: .infinity)
					.background(
						isApplying ? model.accentColor.opacity(0.12) : Color.white.opacity(0.03),
						in: .rect(cornerRadius: 12)
					)
					.overlay {
						RoundedRectangle(cornerRadius: 12)
							.strokeBorder(
								isApplying ? model.accentColor : Color.white.opacity(0.07),
								lineWidth: isApplying ? 2 : 1
							)
					}
					.shadow(
						color: isApplying ? model.accentColor.opacity(0.4) : .clear,
						radius: 8,
						x: 0,
						y: 2
					)
				}
				.buttonStyle(.plain)
				.disabled(applyingItemID != nil)
			}
		}
	}

	private func applyAvatar(_ avatar: PresetAvatar) {
		guard applyingItemID == nil else { return }
		applyingItemID = avatar.id
		Task {
			if let data = try? await PresetCatalogService.shared.imageData(
				for: avatar.url, cacheKey: avatar.id
			),
				let squircle = AppIconRenderer.createAvatarSquircle(from: data)
			{
				model.applyDirectCustomAppIcon(image: squircle)
				dismiss()
			} else {
				applyingItemID = nil
			}
		}
	}

	private func applyWallpaper(_ wp: PresetWallpaper) {
		guard applyingItemID == nil else { return }
		applyingItemID = wp.id
		Task {
			if let data = try? await PresetCatalogService.shared.imageData(
				for: wp.url, cacheKey: wp.id
			) {
				model.applyDirectCustomArtwork(data: data)
				dismiss()
			} else {
				applyingItemID = nil
			}
		}
	}
}

/// A smooth, disk-backed image loader that caches images permanently in `~/Library/Caches/...`
/// preventing redundant re-downloads and rate-limit drops during scrolling.
private struct CachedPresetImage: View {
	let url: URL
	let cacheKey: String
	var contentMode: ContentMode = .fill
	var placeholderIcon: String = "photo"

	@State private var image: NSImage?
	@State private var hasFailed = false

	var body: some View {
		Group {
			if let image {
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: contentMode)
			} else if hasFailed {
				ZStack {
					Color.white.opacity(0.04)
					Image(systemName: placeholderIcon)
						.font(.system(size: 24))
						.foregroundStyle(Color.white.opacity(0.15))
				}
			} else {
				ZStack {
					Color.white.opacity(0.04)
					ProgressView()
						.controlSize(.small)
				}
			}
		}
		.task(id: url) {
			guard image == nil else { return }
			if let data = try? await PresetCatalogService.shared.imageData(
				for: url, cacheKey: cacheKey
			),
				let nsImage = NSImage(data: data)
			{
				self.image = nsImage
				self.hasFailed = false
			} else {
				self.hasFailed = true
			}
		}
	}
}
