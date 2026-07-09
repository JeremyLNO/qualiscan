import Foundation
import Security

/// Crazy Bee Labs account (returned by the accounts API).
struct CBLUser: Codable, Equatable {
    let id: String
    let email: String
    let name: String?
}

enum AuthError: LocalizedError {
    case server(String)
    case network
    case cancelled
    var errorDescription: String? {
        switch self {
        case .server(let m): return m
        case .network: return L.t("auth_network_error")
        case .cancelled: return nil
        }
    }
}

enum AuthConfig {
    /// Accounts API (crazybeelabs-app). Change if the accounts app is on another host.
    static let baseURL = "https://crazybeelabs.com"
}

/// Session state + accounts API client. Token lives in the Keychain; the app is
/// fully usable signed-out — an account only unifies with Crazy Bee Labs.
@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published private(set) var user: CBLUser?
    var isSignedIn: Bool { user != nil }

    private let tokenKey = "cbl.auth.token"
    private let userKey = "cbl.auth.user"

    private init() {
        if Keychain.get(tokenKey) != nil,
           let data = UserDefaults.standard.data(forKey: userKey),
           let u = try? JSONDecoder().decode(CBLUser.self, from: data) {
            user = u
        }
    }

    private var token: String? { Keychain.get(tokenKey) }

    // MARK: - Flows

    func signInWithEmail(_ email: String, password: String) async throws {
        let r: AuthResponse = try await send("/api/auth/mobile/login", "POST",
                                             ["email": email, "password": password])
        persist(r)
    }

    func register(name: String, email: String, password: String) async throws {
        var body: [String: Any] = ["email": email, "password": password]
        if !name.isEmpty { body["name"] = name }
        let r: AuthResponse = try await send("/api/auth/mobile/register", "POST", body)
        persist(r)
    }

    func signInWithApple(identityToken: String, name: String?) async throws {
        var body: [String: Any] = ["identityToken": identityToken]
        if let name, !name.isEmpty { body["name"] = name }
        let r: AuthResponse = try await send("/api/auth/mobile/apple", "POST", body)
        persist(r)
    }

    func signInWithGoogle(idToken: String, name: String?) async throws {
        var body: [String: Any] = ["idToken": idToken]
        if let name, !name.isEmpty { body["name"] = name }
        let r: AuthResponse = try await send("/api/auth/mobile/google", "POST", body)
        persist(r)
    }

    func requestPasswordReset(email: String) async throws {
        let _: EmptyResponse = try await send("/api/auth/forgot-password", "POST", ["email": email])
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await send("/api/account", "DELETE", ["confirm": "DELETE"], auth: true)
        signOut()
    }

    func signOut() {
        Keychain.delete(tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        user = nil
    }

    // MARK: - Internals

    private func persist(_ r: AuthResponse) {
        Keychain.set(tokenKey, r.token)
        user = r.user
        if let d = try? JSONEncoder().encode(r.user) { UserDefaults.standard.set(d, forKey: userKey) }
    }

    private struct AuthResponse: Decodable { let token: String; let user: CBLUser }
    private struct EmptyResponse: Decodable {}
    private struct APIError: Decodable { let error: String? }

    private func send<T: Decodable>(_ path: String, _ method: String, _ body: [String: Any]?,
                                    auth: Bool = false) async throws -> T {
        guard let url = URL(string: AuthConfig.baseURL + path) else { throw AuthError.network }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: req) }
        catch { throw AuthError.network }

        guard let http = response as? HTTPURLResponse else { throw AuthError.network }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIError.self, from: data))?.error
            throw AuthError.server(msg ?? "Error \(http.statusCode)")
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Keychain

enum Keychain {
    static func set(_ key: String, _ value: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func delete(_ key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrAccount as String: key] as CFDictionary)
    }
}

// MARK: - Google Sign-In bridge
//
// Compiles to nothing until the GoogleSignIn SPM package is added. To finish Google:
//   1. Add https://github.com/google/GoogleSignIn-iOS via Swift Package Manager.
//   2. Create a Google Cloud OAuth *iOS* client id; put it in Info.plist as `GIDClientID`,
//      and add its reversed client id to URL Types (CFBundleURLSchemes).
//   3. Add `company.lno.qualiscan`'s client id to the backend `GOOGLE_CLIENT_IDS` env.
// Then this bridge lights up automatically.
#if canImport(GoogleSignIn)
import GoogleSignIn
import UIKit

enum GoogleSignInBridge {
    @MainActor
    static func signIn(lang: AppLanguage,
                       completion: @escaping (Result<(idToken: String, name: String?), Error>) -> Void) {
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.keyWindow?.rootViewController else {
            completion(.failure(AuthError.server("No presenter available."))); return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            if let error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    completion(.failure(AuthError.cancelled))
                } else {
                    completion(.failure(error))
                }
                return
            }
            guard let idToken = result?.user.idToken?.tokenString else {
                completion(.failure(AuthError.server("No Google id token."))); return
            }
            completion(.success((idToken, result?.user.profile?.name)))
        }
    }
}
#endif
