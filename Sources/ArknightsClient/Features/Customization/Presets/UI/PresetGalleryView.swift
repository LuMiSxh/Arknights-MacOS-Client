// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct PresetGalleryView: View {
	let catalog: PresetCatalogService
	let customization: CustomizationController
	let lifecycle: LauncherLifecycleStore
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

	init(
		catalog: PresetCatalogService,
		customization: CustomizationController,
		lifecycle: LauncherLifecycleStore,
		destination: PresetGalleryDestination
	) {
		self.catalog = catalog
		self.customization = customization
		self.lifecycle = lifecycle
		self.destination = destination
	}

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			VStack(spacing: 0) {
				PresetGalleryHeader(
					destination: destination,
					catalog: catalog,
					customization: customization,
					avatars: avatars,
					showsIconStylePreview: $showsIconStylePreview
				)
				Divider().overlay(Color.white.opacity(0.08))

				searchBar
					.padding(.horizontal, 24)
					.padding(.vertical, 14)

				ScrollView {
					Group {
						if isLoading {
							PresetGalleryLoadingView(text: destination.loadingText)
						} else if destination == .artwork {
							if filteredWallpapers.isEmpty {
								PresetGalleryEmptyView(
									text: destination.emptyText, systemImage: "photo")
							} else {
								wallpapersGrid
							}
						} else {
							if filteredAvatars.isEmpty {
								PresetGalleryEmptyView(
									text: destination.emptyText, systemImage: "person.crop.square"
								)
							} else {
								avatarsGrid
							}
						}
					}
					.padding(.horizontal, 24)
					.padding(.bottom, 64)
				}
				.contentMargins(.top, 8, for: .scrollIndicators)
				.contentMargins(.bottom, 24, for: .scrollIndicators)
			}

			FloatingActionFooterFade(height: 56)

			FloatingActionBar(tint: customization.hudTintColor) {
				FloatingDoneButton(accentColor: customization.accentColor) {
					dismiss()
				}
			}
			.padding(.trailing, 24)
			.padding(.bottom, 18)
		}
		.frame(width: 760, height: 570)
		.background(
			ZStack {
				LauncherVisuals.modalBackground
				customization.hudTintColor
			}
		)
		.preferredColorScheme(.dark)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.3),
			value: customization.dynamicThemeHue
		)
		.onExitCommand(perform: dismiss.callAsFunction)
		.task(id: destination) {
			if destination == .artwork {
				wallpapers = await catalog.fetchWallpapers()
			} else {
				avatars = await catalog.fetchAvatars()
			}
			isLoading = false
		}
	}

	private var searchBar: some View {
		ThemedTextField(
			L10n.string(CustomizationStrings.searchLabel),
			prompt: L10n.string(destination.searchPlaceholder),
			text: $searchText,
			systemImage: "magnifyingglass",
			accentColor: customization.accentColor
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
		return wallpapers.filter { $0.title.localizedStandardContains(query) }
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
								catalog: catalog,
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
										.tint(customization.accentColor)
								}
								.clipShape(RoundedRectangle(cornerRadius: 22))
							}
						}
						.frame(width: 104, height: 104)
						.overlay {
							RoundedRectangle(cornerRadius: 22)
								.strokeBorder(
									isApplying
										? customization.accentColor : Color.white.opacity(0.14),
									lineWidth: isApplying ? 2.5 : 1.5
								)
						}
						.shadow(
							color: isApplying
								? customization.accentColor.opacity(0.5) : Color.black.opacity(0.4),
							radius: isApplying ? 8 : 5,
							x: 0,
							y: 3
						)

						Text(avatar.name)
							.font(.caption.weight(isApplying ? .bold : .medium))
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? customization.accentColor : .primary)
							.frame(maxWidth: 130)
					}
					.padding(.vertical, 4)
					.frame(maxWidth: .infinity)
					.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: 22))
				.disabled(applyingItemID != nil)
				.accessibilityLabel(avatar.name)
				.accessibilityHint(CustomizationStrings.operatorApplyHelp(avatar.name))
				.accessibilityValue(isApplying ? Text(CustomizationStrings.applying) : Text(""))
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
								catalog: catalog,
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
											.tint(customization.accentColor)
										Text(CustomizationStrings.applying)
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
							.lineLimit(2)
							.truncationMode(.tail)
							.foregroundStyle(isApplying ? customization.accentColor : .primary)
					}
					.padding(8)
					.frame(maxWidth: .infinity)
					.background(
						isApplying
							? customization.accentColor.opacity(0.12) : Color.white.opacity(0.03),
						in: .rect(cornerRadius: 12)
					)
					.overlay {
						RoundedRectangle(cornerRadius: 12)
							.strokeBorder(
								isApplying
									? customization.accentColor : Color.white.opacity(0.07),
								lineWidth: isApplying ? 2 : 1
							)
					}
					.shadow(
						color: isApplying ? customization.accentColor.opacity(0.4) : .clear,
						radius: 8,
						x: 0,
						y: 2
					)
				}
				.buttonStyle(.plain)
				.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: 12))
				.disabled(applyingItemID != nil)
				.accessibilityLabel(wp.title)
				.accessibilityHint(CustomizationStrings.wallpaperApplyHelp(wp.title))
				.accessibilityValue(isApplying ? Text(CustomizationStrings.applying) : Text(""))
			}
		}
	}

	private func applyAvatar(_ avatar: PresetAvatar) {
		guard applyingItemID == nil else { return }
		applyingItemID = avatar.id
		Task {
			do {
				let data = try await catalog.imageData(
					for: avatar.url, cacheKey: avatar.id
				)
				customization.applyPresetAvatar(data: data)
				dismiss()
			} catch {
				applyingItemID = nil
				lifecycle.show(error)
			}
		}
	}

	private func applyWallpaper(_ wp: PresetWallpaper) {
		guard applyingItemID == nil else { return }
		applyingItemID = wp.id
		Task {
			do {
				let data = try await catalog.imageData(
					for: wp.url, cacheKey: wp.id
				)
				await customization.applyDirectCustomArtwork(data: data)
				dismiss()
			} catch {
				applyingItemID = nil
				lifecycle.show(error)
			}
		}
	}
}
