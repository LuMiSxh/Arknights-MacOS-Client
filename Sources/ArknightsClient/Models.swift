import Foundation

struct APIEnvelope<Value: Decodable>: Decodable {
  let code: Int
  let data: Value
  let msg: String?
}

struct GameConfiguration: Codable, Sendable {
  let gameLowestVersion: String
  let gameLatestVersion: String
  let gameLatestFilePath: String
  let gameStartExeName: String
  let gameStartParams: [String]
  let gameUninstallScript: String
  let decompressionSize: String

  var executableName: String {
    gameStartExeName.lowercased().hasSuffix(".exe")
      ? gameStartExeName
      : "\(gameStartExeName).exe"
  }
}

struct CDNConfiguration: Codable, Sendable {
  let primaryCdn: URL
  let backUpCdn: URL
}

struct ManifestLocation: Codable, Sendable {
  let url: URL
}

struct GameManifest: Codable, Sendable {
  let source: String
  let file: [ManifestFile]
}

struct ManifestFile: Codable, Hashable, Sendable {
  let path: String
  let hash: String
  let size: String

  var byteCount: Int64 {
    Int64(size) ?? 0
  }
}

struct DownloadProgress: Sendable {
  let downloadedBytes: Int64
  let totalBytes: Int64
  let completedFiles: Int
  let totalFiles: Int
  let currentFile: String

  var fraction: Double {
    guard totalBytes > 0 else { return 0 }
    return min(1, Double(downloadedBytes) / Double(totalBytes))
  }
}

struct InstallResult: Sendable {
  let downloadedFiles: Int
  let downloadedBytes: Int64
  let installDirectory: URL
}

struct InstalledState: Codable, Sendable {
  let version: String
  let basis: String
  let source: String
  let installedAt: Date
}

enum LauncherPhase: Equatable, Sendable {
  case checking
  case ready
  case downloading
  case launching
  case running(processIdentifier: Int32)
  case failed(String)

  var title: String {
    switch self {
    case .checking: "Checking version"
    case .ready: "Ready"
    case .downloading: "Downloading game files"
    case .launching: "Starting Windows runtime"
    case .running: "Game started"
    case .failed: "Action failed"
    }
  }
}

enum LauncherError: LocalizedError {
  case invalidResponse
  case server(code: Int, message: String)
  case invalidManifestPath(String)
  case invalidDownloadResponse(status: Int, path: String)
  case downloadedSizeMismatch(path: String, expected: Int64, actual: Int64)
  case checksumMismatch(path: String, expected: String, actual: String)
  case cannotCreateFile(URL)
  case missingConfiguration
  case gameNotInstalled(URL)
  case wineRuntimeMissing
  case runtimeExited(status: Int32, log: URL)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "Yostar's server returned an invalid response."
    case .server(let code, let message):
      "Yostar API error \(code): \(message)"
    case .invalidManifestPath(let path):
      "Unsafe path in game manifest: \(path)"
    case .invalidDownloadResponse(let status, let path):
      "Download for \(path) returned HTTP \(status)."
    case .downloadedSizeMismatch(let path, let expected, let actual):
      "\(path) has \(actual) bytes instead of \(expected)."
    case .checksumMismatch(let path, let expected, let actual):
      "CRC64 check for \(path) failed (\(actual), expected \(expected))."
    case .cannotCreateFile(let url):
      "Could not create temporary file: \(url.path)"
    case .missingConfiguration:
      "The current game configuration has not been loaded yet."
    case .gameNotInstalled(let url):
      "Arknights.exe was not found: \(url.path)"
    case .wineRuntimeMissing:
      "No compatible Wine or CrossOver runtime found."
    case .runtimeExited(let status, let log):
      "The Windows runtime exited with status \(status). See \(log.path)."
    }
  }
}
