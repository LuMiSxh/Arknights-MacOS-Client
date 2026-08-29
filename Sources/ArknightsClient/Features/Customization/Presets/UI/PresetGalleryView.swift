// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PresetGalleryView: View {
	@Bindable var model: LauncherViewModel
	let destination: PresetGalleryDestination
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var searchText = ""
	@State private var avatars: [PresetAvatar] = []
	@State private var wallpapers: [PresetWallpaper] = []
	@State private var isLoading = true
	@State private var applyingItemID: String?
	@State private var showsIconStylePreview = false

	private let avatarColumns = [
		GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)
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

				searchBar
					.padding(.horizontal, 24)
					.padding(.vertical, 14)

				ScrollView {
					Group {
						if isLoading {
							PresetGalleryLoadingView(
								text: destination == .artwork
									? "Loading official wallpapers…" : "Loading operators…"
							)
						} else if destination == .artwork {
							wallpapersGrid
						} else {
							avatarsGrid
						}
					}
					.padding(.horizontal, 24)
					.padding(.bottom, 64)
				}
				.contentMargins(.top, 8, for: .scrollIndicators)
				.contentMargins(.bottom, 24, for: .scrollIndicators)
			}

			LinearGradient(
				colors: [.clear, Color.black.opacity(0.45)],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: 56)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
			.allowsHitTesting(false)

			FloatingActionBar(tint: model.hudTintColor) {
				FloatingDoneButton(accentColor: model.accentColor) {
					dismiss()
				}
			}
			.padding(.trailing, 24)
			.padding(.bottom, 18)
		}
		.frame(width: 760, height: 570)
		.background(
			ZStack {
				Color(red: 0.07, green: 0.07, blue: 0.08)
				model.hudTintColor
			}
		)
		.preferredColorScheme(.dark)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.3),
			value: model.dynamicThemeHue
		)
		.task(id: destination) {
			if destination == .artwork {
				wallpapers = await model.presetCatalog.fetchWallpapers()
			} else {
				avatars = await model.presetCatalog.fetchAvatars()
			}
			isLoading = false
		}
	}

	private var header: some View {
		HStack {
			VStack(alignment: .leading, spacing: 3) {
				Text(destination.title)
					.font(.title3.bold())
				Text(destination.subtitle)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			if destination == .operatorIcons {
				CapsuleActionButton(
					title: "Preview Styles", systemImage: "dock.rectangle",
					tone: .accent(model.accentColor)
				) {
					showsIconStylePreview = true
				}
				.controlSize(.small)
				.popover(isPresented: $showsIconStylePreview, arrowEdge: .top) {
					OperatorIconStylePreview(
						catalog: model.presetCatalog,
						avatar: avatars.first,
						accentHue: model.dynamicThemeHue,
						accentColor: model.accentColor
					)
				}
			}
		}
		.padding(.horizontal, 24)
		.padding(.vertical, 16)
	}

	private var searchBar: some View {
		ThemedTextField(
			"Search gallery",
			prompt: destination.searchPlaceholder,
			text: $searchText,
			systemImage: "magnifyingglass",
			accentColor: model.accentColor
		)
	}

	private var filteredAvatars: [PresetAvatar] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		if query.isEmpty { return avatars }
		return avatars.filter { $0.name.localizedStandardContains(query) }
	}

	private var filteredWallpapers: [PresetWallpaper] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		if query.isEmpty { return wallpapers }
		return wallpapers.filter { wallpaper in
			wallpaper.title.localizedStandardContains(query)
				|| WallpaperTagCatalog.tags(for: wallpaper.id).contains {
					$0.localizedStandardContains(query)
				}
		}
	}

	private var avatarsGrid: some View {
		LazyVGrid(columns: avatarColumns, spacing: 18) {
			ForEach(filteredAvatars) { avatar in
				let isApplying = applyingItemID == avatar.id
				Button {
					applyAvatar(avatar)
				} label: {
					VStack(spacing: 6) {
						ZStack {
							CachedPresetImage(
								catalog: model.presetCatalog,
								url: avatar.url,
								cacheKey: avatar.id,
								contentMode: .fit,
								placeholderIcon: "person.crop.square"
							)
							.frame(width: 104, height: 104)
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
							.clipShape(RoundedRectangle(cornerRadius: 22))

							if isApplying {
								ZStack {
									Color.black.opacity(0.65)
									ProgressView()
										.controlSize(.small)
										.tint(model.accentColor)
								}
								.clipShape(RoundedRectangle(cornerRadius: 22))
							}
						}
						.frame(width: 104, height: 104)
						.overlay {
							RoundedRectangle(cornerRadius: 22)
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
							.font(.caption.weight(isApplying ? .bold : .medium))
							.lineLimit(1)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? model.accentColor : .primary)
							.frame(maxWidth: 130)
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
								catalog: model.presetCatalog,
								url: wp.thumbnailURL ?? wp.url,
								cacheKey: "thumb_\(wp.id)",
								contentMode: .fill,
								placeholderIcon: "photo"
							)
							.frame(minWidth: 0, maxWidth: .infinity)
							.frame(height: 105)
							.clipped()
							.clipShape(RoundedRectangle(cornerRadius: 10))

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
			do {
				let data = try await model.presetCatalog.imageData(
					for: avatar.url, cacheKey: avatar.id
				)
				model.applyPresetAvatar(data: data)
				dismiss()
			} catch {
				applyingItemID = nil
				model.show(error)
			}
		}
	}

	private func applyWallpaper(_ wp: PresetWallpaper) {
		guard applyingItemID == nil else { return }
		applyingItemID = wp.id
		Task {
			do {
				let data = try await model.presetCatalog.imageData(
					for: wp.url, cacheKey: wp.id
				)
				await model.applyDirectCustomArtwork(data: data)
				dismiss()
			} catch {
				applyingItemID = nil
				model.show(error)
			}
		}
	}
}
