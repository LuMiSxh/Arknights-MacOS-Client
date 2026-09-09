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
	@State private var committedTags: [String] = []
	@State private var selectedCategory: WallpaperCategory?
	@State private var avatars: [PresetAvatar] = []
	@State private var wallpapers: [PresetWallpaper] = []
	@State private var isLoading = true
	@State private var applyingItemID: String?
	@State private var showsIconStylePreview = false
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
		let hasSearchQuery = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let filteredAvatars = PresetCatalogSearch.avatars(matching: searchText, in: avatars)
		let filteredWallpapers = PresetGallerySearch.wallpapers(
			matching: searchText,
			committedTags: committedTags,
			category: selectedCategory,
			in: wallpapers
		)
		let wallpaperTerms = PresetGallerySearch.suggestions(
			matching: searchText,
			committedTags: committedTags,
			category: selectedCategory,
			in: wallpapers
		)
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
				HStack(spacing: 10) {
					PresetGallerySearchBar(
						destination: destination,
						accentColor: customization.accentColor,
						searchText: $searchText,
						committedTags: $committedTags
					)
					.frame(maxWidth: .infinity)
					if destination == .artwork {
						WallpaperCategoryFilter(
							selection: $selectedCategory,
							accentColor: customization.accentColor,
							counts: wallpaperCategoryCounts,
							operatorCounts: operatorArtCounts(among: filteredWallpapers),
							onSelectOperator: { tag in
								if !committedTags.contains(tag) { committedTags.append(tag) }
							}
						)
					}
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 14)
				PresetGallerySuggestions(
					destination: destination,
					avatars: hasSearchQuery ? filteredAvatars : [],
					wallpaperTerms: hasSearchQuery ? wallpaperTerms : []
				) { selection in
					searchText =
						destination == .artwork
						? WallpaperSearch.applyingSuggestion(selection, to: searchText)
						: selection
				}
				.padding(.horizontal, 24)
				ScrollView {
					Group {
						if isLoading {
							PresetGalleryLoadingView(text: destination.loadingText)
						} else if destination == .artwork {
							if filteredWallpapers.isEmpty {
								PresetGalleryEmptyView(
									text: destination.emptyText, systemImage: "photo")
							} else {
								PresetWallpaperGrid(
									catalog: catalog,
									accentColor: customization.accentColor,
									wallpapers: filteredWallpapers,
									applyingItemID: applyingItemID,
									onSelect: applyWallpaper
								)
							}
						} else {
							if filteredAvatars.isEmpty {
								PresetGalleryEmptyView(
									text: destination.emptyText, systemImage: "person.crop.square"
								)
							} else {
								PresetAvatarGrid(
									catalog: catalog,
									accentColor: customization.accentColor,
									avatars: filteredAvatars,
									applyingItemID: applyingItemID,
									onSelect: applyAvatar
								)
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
			isLoading = true
			let taskDestination = destination
			if destination == .artwork {
				wallpapers = await catalog.fetchWallpapers()
			} else {
				avatars = await catalog.fetchAvatars()
			}
			guard !Task.isCancelled, taskDestination == destination else { return }
			isLoading = false
		}
		// Fetched separately from the wallpapers above so the operator roster (needed only to
		// identify operators among wallpaper tags for the filter's submenu) never delays the
		// Artwork grid itself from appearing.
		.task(id: destination) {
			guard destination == .artwork else { return }
			let fetchedAvatars = await catalog.fetchAvatars()
			guard !Task.isCancelled, destination == .artwork else { return }
			avatars = fetchedAvatars
		}
	}

	// How many wallpapers each category filter option would show for the current search text
	// and committed tag pills, regardless of which category (if any) is currently selected —
	// so switching categories is an informed choice rather than a guess. `nil` is the "All
	// Types" option's own total.
	private var wallpaperCategoryCounts: [WallpaperCategory?: Int] {
		Dictionary(
			uniqueKeysWithValues: ([nil] + WallpaperCategory.allCases.map { $0 }).map { category in
				(
					category,
					PresetGallerySearch.wallpapers(
						matching: searchText, committedTags: committedTags, category: category,
						in: wallpapers
					).count
				)
			}
		)
	}

	// Every operator identifiable among `visibleWallpapers`, with how many of them feature
	// them — sorted most-featured first. A tag counts as an operator only if it matches a real
	// operator's name from the character roster, so unrelated tags (locations, event names)
	// never show up here.
	private func operatorArtCounts(among visibleWallpapers: [PresetWallpaper]) -> [OperatorArtCount]
	{
		guard !avatars.isEmpty else { return [] }
		let namesByNormalizedTag = Dictionary(
			avatars.map { (WallpaperSearch.normalized($0.name), $0.name) },
			uniquingKeysWith: { first, _ in first }
		)
		var counts: [String: Int] = [:]
		for wallpaper in visibleWallpapers {
			for tag in WallpaperTagCatalog.tags(for: wallpaper.id) {
				guard namesByNormalizedTag[WallpaperSearch.normalized(tag)] != nil else { continue }
				counts[tag, default: 0] += 1
			}
		}
		return counts.compactMap { tag, count in
			namesByNormalizedTag[WallpaperSearch.normalized(tag)].map {
				OperatorArtCount(tag: tag, displayName: $0, count: count)
			}
		}
		.sorted { lhs, rhs in
			lhs.count != rhs.count
				? lhs.count > rhs.count
				: lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
		}
	}
	private func applyAvatar(_ avatar: PresetAvatar) {
		applyPreset(id: avatar.id, url: avatar.url) { data in
			await customization.applyPresetAvatar(data: data)
		}
	}
	private func applyWallpaper(_ wp: PresetWallpaper) {
		applyPreset(id: wp.id, url: wp.url) { data in
			await customization.applyDirectCustomArtwork(data: data)
		}
	}

	private func applyPreset(
		id: String,
		url: URL,
		apply: @escaping @MainActor (Data) async -> Void
	) {
		guard applyingItemID == nil else { return }
		applyingItemID = id
		let taskDestination = destination
		Task {
			do {
				let data = try await catalog.imageData(for: url, cacheKey: id)
				guard isCurrentApplication(id: id, destination: taskDestination) else { return }
				await apply(data)
				guard isCurrentApplication(id: id, destination: taskDestination) else { return }
				dismiss()
			} catch {
				guard isCurrentApplication(id: id, destination: taskDestination) else { return }
				applyingItemID = nil
				lifecycle.show(error)
			}
		}
	}

	private func isCurrentApplication(id: String, destination expected: PresetGalleryDestination)
		-> Bool
	{
		!Task.isCancelled && destination == expected && applyingItemID == id
	}
}
