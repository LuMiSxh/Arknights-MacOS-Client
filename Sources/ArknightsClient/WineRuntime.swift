import Foundation

struct WineRuntime: Sendable {
  let executableURL: URL
  let displayName: String

  static func discover(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) -> WineRuntime? {
    var candidates: [(String, String)] = []

    if let bundled = Bundle.main.resourceURL {
      candidates.append((bundled.appending(path: "Runtime/bin/wine64").path, "Bundled Wine"))
      candidates.append((bundled.appending(path: "Runtime/bin/wine").path, "Bundled Wine"))
    }

    candidates += [
      ("/opt/homebrew/bin/wine64", "Homebrew Wine"),
      ("/opt/homebrew/bin/wine", "Homebrew Wine"),
      ("/usr/local/bin/wine64", "Homebrew Wine"),
      ("/usr/local/bin/wine", "Homebrew Wine"),
      ("/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine64", "Wine Stable"),
      ("/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine64", "Wine Staging"),
      ("/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine64", "Wine Devel"),
      ("/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine64", "Wine Crossover"),
      (
        "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64",
        "Game Porting Toolkit"
      ),
      (
        "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine",
        "CrossOver"
      ),
    ]

    if let path = environment["PATH"] {
      for directory in path.split(separator: ":") {
        candidates.append((URL(filePath: String(directory)).appending(path: "wine64").path, "Wine"))
        candidates.append((URL(filePath: String(directory)).appending(path: "wine").path, "Wine"))
      }
    }

    for (path, name) in candidates {
      if fileManager.isExecutableFile(atPath: path) {
        return WineRuntime(executableURL: URL(filePath: path), displayName: name)
      }
    }
    return nil
  }

  func launch(gameExecutable: URL, prefixDirectory: URL) throws -> Int32 {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: prefixDirectory, withIntermediateDirectories: true)

    var environment = ProcessInfo.processInfo.environment
    environment["WINEPREFIX"] = prefixDirectory.path
    environment["WINEDEBUG"] = "-all"
    environment["PATH"] = [
      executableURL.deletingLastPathComponent().path,
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "/bin",
    ].joined(separator: ":")

    let process = Process()
    process.executableURL = executableURL
    process.arguments = [gameExecutable.path]
    process.currentDirectoryURL = gameExecutable.deletingLastPathComponent()
    process.environment = environment
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    return process.processIdentifier
  }
}
