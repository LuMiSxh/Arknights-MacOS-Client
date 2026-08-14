import CryptoKit
import Foundation

actor LauncherAPI {
  static let launcherVersion = "1.8.1"

  private let baseURL = URL(string: "https://api-launcher-en.yo-star.com")!
  private let gameTag = "Arknights_EN"
  private let salt = "DE7108E9B2842FD460F4777702727869"
  private let session: URLSession
  private let decoder: JSONDecoder

  init(session: URLSession = .shared) {
    self.session = session
    decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
  }

  func gameConfiguration() async throws -> GameConfiguration {
    try await request(path: "/api/launcher/game/config")
  }

  func cdnConfiguration() async throws -> CDNConfiguration {
    try await request(path: "/api/launcher/advanced/game/download/cdn")
  }

  func manifest(for configuration: GameConfiguration) async throws -> GameManifest {
    var components = URLComponents(
      url: baseURL.appending(path: "/api/launcher/game/config/json"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "version", value: configuration.gameLatestVersion),
      URLQueryItem(name: "file_path", value: configuration.gameLatestFilePath),
    ]
    guard let locationURL = components?.url else {
      throw LauncherError.invalidResponse
    }
    let location: ManifestLocation = try await request(url: locationURL)

    var manifestRequest = URLRequest(url: location.url)
    manifestRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    let (data, response) = try await session.data(for: manifestRequest)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw LauncherError.invalidResponse
    }
    return try decoder.decode(GameManifest.self, from: data)
  }

  func authorizationHeader(timestamp: Int64 = Int64(Date().timeIntervalSince1970)) -> String {
    let head =
      "{\"game_tag\":\"\(gameTag)\",\"time\":\(timestamp),\"version\":\"\(Self.launcherVersion)\"}"
    let digest = Insecure.MD5.hash(data: Data("\(head)\(salt)".utf8))
    let signature = digest.map { String(format: "%02x", $0) }.joined()
    return "{\"head\":\(head),\"sign\":\"\(signature)\"}"
  }

  private func request<Value: Decodable>(path: String) async throws -> Value {
    try await request(url: baseURL.appending(path: path))
  }

  private func request<Value: Decodable>(url: URL) async throws -> Value {
    var request = URLRequest(url: url)
    request.setValue(authorizationHeader(), forHTTPHeaderField: "Authorization")
    request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw LauncherError.invalidResponse
    }
    let envelope = try decoder.decode(APIEnvelope<Value>.self, from: data)
    guard envelope.code == 200 else {
      throw LauncherError.server(code: envelope.code, message: envelope.msg ?? "Unbekannter Fehler")
    }
    return envelope.data
  }
}
