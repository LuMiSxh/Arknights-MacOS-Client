// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// The facts `environment.json` carries, in human-readable form.
///
/// Every value is something the app already knows locally; collecting it makes no network call.
/// The composition root fills the feature-owned groups, and this type only names and encodes them.
package struct DiagnosticsEnvironment: Codable, Sendable, Equatable {
	private static let currentSchema = 1

	package struct App: Codable, Sendable, Equatable {
		package var version: String
		package var build: String?
		/// `applications`, `userApplications`, `translocated`, or `other`.
		package var location: String

		package static func current(bundle: Bundle = .main) -> App {
			App(
				version: IssueReportURL.appVersion,
				build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
				location: Self.location(ofBundleAt: bundle.bundleURL.path)
			)
		}

		package static func location(ofBundleAt path: String) -> String {
			if path.contains("/AppTranslocation/") { return "translocated" }
			if path.hasPrefix("/Applications/") { return "applications" }
			if path.hasPrefix(NSHomeDirectory() + "/Applications/") { return "userApplications" }
			return "other"
		}
	}

	package struct Display: Codable, Sendable, Equatable {
		/// Size in points, for example "1512x982".
		package var size: String
		package var scale: Double
		package var hasNotch: Bool

		package init(size: String, scale: Double, hasNotch: Bool) {
			self.size = size
			self.scale = scale
			self.hasNotch = hasNotch
		}
	}

	package struct System: Codable, Sendable, Equatable {
		package var macOS: String
		package var chip: String
		package var memoryGB: Int
		/// The launcher's Intel translation check, such as `available` or `rosetta-missing`.
		package var rosetta: String
		package var lowPowerMode: Bool
		package var displays: [Display]
		package var timeZone: String

		package static func current(rosetta: String, displays: [Display]) -> System {
			System(
				macOS: ProcessInfo.processInfo.operatingSystemVersionString,
				chip: IssueReportURL.chipName,
				memoryGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
				rosetta: rosetta,
				lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
				displays: displays,
				timeZone: TimeZone.current.identifier
			)
		}
	}

	/// One failure the launcher presented, with the log line's own ISO 8601 timestamp.
	package struct Failure: Codable, Sendable, Equatable {
		package var time: String
		package var code: String
		package var operation: String

		package init(time: String, code: String, operation: String) {
			self.time = time
			self.code = code
			self.operation = operation
		}
	}

	package struct PrefixMigrations: Codable, Sendable, Equatable {
		package var runtimeRevision: String
		package var completed: [String]
		/// When the migration state was last written. The state file stores no per-step times.
		package var updatedAt: Date?

		package init(runtimeRevision: String, completed: [String], updatedAt: Date?) {
			self.runtimeRevision = runtimeRevision
			self.completed = completed
			self.updatedAt = updatedAt
		}
	}

	package struct Runtime: Codable, Sendable, Equatable {
		package var selectedLane: String
		package var name: String?
		package var installedVersions: [String: String]
		package var metalFXSpatialUpscaling: String
		/// The pinned prefix revision of the selected lane, when the pin is readable.
		package var pinnedPrefixRevision: Int?
		package var prefixMigrations: PrefixMigrations?

		package init(
			selectedLane: String, name: String?, installedVersions: [String: String],
			metalFXSpatialUpscaling: String, pinnedPrefixRevision: Int?,
			prefixMigrations: PrefixMigrations?
		) {
			self.selectedLane = selectedLane
			self.name = name
			self.installedVersions = installedVersions
			self.metalFXSpatialUpscaling = metalFXSpatialUpscaling
			self.pinnedPrefixRevision = pinnedPrefixRevision
			self.prefixMigrations = prefixMigrations
		}
	}

	/// The install state file without its file list. The download source and manifest path stay
	/// out because they can hold paths.
	package struct InstallState: Codable, Sendable, Equatable {
		package var schemaVersion: Int
		package var version: String
		package var installedAt: Date

		package init(schemaVersion: Int, version: String, installedAt: Date) {
			self.schemaVersion = schemaVersion
			self.version = version
			self.installedAt = installedAt
		}
	}

	package struct Volume: Codable, Sendable, Equatable {
		package var freeBytes: Int64?
		package var fileSystem: String?

		/// The free space and file system type of the volume that holds `url`, or its nearest existing parent.
		package static func containing(_ url: URL, fileManager: FileManager = .default) -> Volume {
			var existing = url
			while !fileManager.fileExists(atPath: existing.path), existing.path != "/" {
				existing.deleteLastPathComponent()
			}
			let free: Int64?
			do {
				free = try existing.resourceValues(
					forKeys: [.volumeAvailableCapacityForImportantUsageKey]
				).volumeAvailableCapacityForImportantUsage
			} catch {
				// The report omits a fact it cannot read.
				free = nil
			}
			var status = statfs()
			let fileSystem: String? =
				statfs(existing.path, &status) == 0
				? withUnsafePointer(to: &status.f_fstypename) {
					$0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) {
						String(cString: $0)
					}
				} : nil
			return Volume(freeBytes: free, fileSystem: fileSystem)
		}
	}

	package struct Game: Codable, Sendable, Equatable {
		package var server: String
		package var installedVersion: String?
		/// The latest version the launcher already knows; it is not fetched for the report.
		package var latestKnownVersion: String?
		package var updateAvailable: Bool
		/// `managed` for the app's own folder, `custom` for a located or moved install.
		package var installLocation: String
		package var volume: Volume
		package var installState: InstallState?
		package var installedServers: [String]

		package init(
			server: String, installedVersion: String?, latestKnownVersion: String?,
			updateAvailable: Bool, installLocation: String, volume: Volume,
			installState: InstallState?, installedServers: [String]
		) {
			self.server = server
			self.installedVersion = installedVersion
			self.latestKnownVersion = latestKnownVersion
			self.updateAvailable = updateAvailable
			self.installLocation = installLocation
			self.volume = volume
			self.installState = installState
			self.installedServers = installedServers
		}
	}

	package struct Settings: Codable, Sendable, Equatable {
		package var displayMode: String
		/// "WIDTHxHEIGHT".
		package var windowSize: String
		/// "native" or "WIDTHxHEIGHT".
		package var fullscreenResolution: String
		package var rendering: String
		package var cursor: String
		package var synchronization: String
		package var frameRateLimit: String
		package var gameMode: Bool
		package var metalPerformanceHUD: Bool

		package init(options: GameLaunchOptions, usesHardwareCursor: Bool) {
			displayMode = options.displayMode.rawValue
			windowSize = options.windowSize.storageValue
			fullscreenResolution = options.fullscreenResolution.storageValue
			rendering = options.renderingMode.rawValue
			cursor = usesHardwareCursor ? "macOS" : "game"
			synchronization = options.synchronizationMode.rawValue
			frameRateLimit = options.frameRateLimit.rawValue
			gameMode = options.usesGameMode
			metalPerformanceHUD = options.usesMetalPerformanceHUD
		}
	}

	package var schema = Self.currentSchema
	package var app: App
	package var system: System
	package var runtime: Runtime
	package var game: Game
	package var settings: Settings
	package var recentFailures: [Failure]

	package init(
		app: App, system: System, runtime: Runtime, game: Game, settings: Settings,
		recentFailures: [Failure]
	) {
		self.app = app
		self.system = system
		self.runtime = runtime
		self.game = game
		self.settings = settings
		self.recentFailures = recentFailures
	}

	/// Pretty-printed JSON with sorted keys, so two reports diff cleanly.
	package func json() throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		encoder.dateEncodingStrategy = .iso8601
		return String(decoding: try encoder.encode(self), as: UTF8.self) + "\n"
	}
}
