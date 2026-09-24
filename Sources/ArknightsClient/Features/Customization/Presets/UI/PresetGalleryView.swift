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
	@State private var searchResults = PresetGallerySearchResults.empty
	@State private var catalogRevision = 0
	@State private var avatarRevision = 0
	@State private var catalogRequestID = 0
	@State private var avatarRequestID = 0
	@State private var catalogReady = false
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
							counts: searchResults.wallpaperCategoryCounts,
							operatorCounts: searchResults.operatorCounts,
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
					accentColor: customization.accentColor,
					avatars: hasSearchQuery ? searchResults.filteredAvatars : [],
					wallpaperTerms: hasSearchQuery ? searchResults.wallpaperTerms : []
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
							if searchResults.filteredWallpapers.isEmpty {
								PresetGalleryEmptyView(
									text: destination.emptyText, systemImage: "photo")
							} else {
								PresetWallpaperGrid(
									catalog: catalog,
									accentColor: customization.accentColor,
									wallpapers: searchResults.filteredWallpapers,
									applyingItemID: applyingItemID,
									onSelect: applyWallpaper
								)
							}
						} else {
							if searchResults.filteredAvatars.isEmpty {
								PresetGalleryEmptyView(
									text: destination.emptyText, systemImage: "person.crop.square"
								)
							} else {
								PresetAvatarGrid(
									catalog: catalog,
									accentColor: customization.accentColor,
									avatars: searchResults.filteredAvatars,
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
			catalogReady = false
			searchResults = .empty
			catalogRequestID &+= 1
			let taskDestination = destination
			let requestID = catalogRequestID
			let requestedRevision = catalogRevision
			do {
				let fetchedWallpapers: [PresetWallpaper]
				let fetchedAvatars: [PresetAvatar]
				if destination == .artwork {
					fetchedWallpapers = await catalog.fetchWallpapers()
					fetchedAvatars = []
				} else {
					fetchedWallpapers = []
					fetchedAvatars = await catalog.fetchAvatars()
				}
				try Task.checkCancellation()
				guard
					taskDestination == destination,
					requestID == catalogRequestID,
					requestedRevision == catalogRevision
				else { return }

				if destination == .artwork {
					wallpapers = fetchedWallpapers
				} else {
					avatars = fetchedAvatars
				}
				catalogRevision &+= 1
				catalogReady = true
			} catch is CancellationError {
				return
			} catch {
				guard
					!Task.isCancelled,
					taskDestination == destination,
					requestID == catalogRequestID,
					requestedRevision == catalogRevision
				else { return }
				if destination == .artwork {
					wallpapers = []
				} else {
					avatars = []
				}
				catalogRevision &+= 1
				catalogReady = true
			}
		}
		// Fetched separately from the wallpapers above so the operator roster (needed only to
		// identify operators among wallpaper tags for the filter's submenu) never delays the
		// Artwork grid itself from appearing.
		.task(id: destination) {
			guard destination == .artwork else { return }
			let taskDestination = destination
			avatarRequestID &+= 1
			let requestID = avatarRequestID
			let requestedRevision = avatarRevision
			do {
				let fetchedAvatars = await catalog.fetchAvatars()
				try Task.checkCancellation()
				guard
					taskDestination == destination,
					requestID == avatarRequestID,
					requestedRevision == avatarRevision
				else { return }
				avatars = fetchedAvatars
				avatarRevision &+= 1
			} catch is CancellationError {
				return
			} catch {
				return
			}
		}
		.task(id: searchQuery) {
			let query = searchQuery
			guard query.catalogReady else { return }
			let sourceAvatars = avatars
			let sourceWallpapers = wallpapers
			do {
				let computed = try await PresetGallerySearch.results(
					for: query.destination,
					searchText: query.searchText,
					committedTags: query.committedTags,
					selectedCategory: query.selectedCategory,
					avatars: sourceAvatars,
					wallpapers: sourceWallpapers
				)
				try Task.checkCancellation()
				guard
					PresetGallerySearch.shouldPublishResults(
						request: query,
						currentQuery: searchQuery,
						isCancelled: Task.isCancelled
					)
				else { return }
				searchResults = computed
				isLoading = false
			} catch is CancellationError {
				return
			} catch {
				guard
					PresetGallerySearch.shouldPublishResults(
						request: query,
						currentQuery: searchQuery,
						isCancelled: Task.isCancelled
					)
				else { return }
				searchResults = .empty
				isLoading = false
				lifecycle.show(error, context: "Preset gallery search")
			}
		}
	}

	private var searchQuery: PresetGallerySearchQuery {
		PresetGallerySearchQuery(
			destination: destination,
			searchText: searchText,
			committedTags: committedTags,
			selectedCategory: selectedCategory,
			catalogRevision: catalogRevision,
			avatarRevision: avatarRevision,
			catalogReady: catalogReady
		)
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
