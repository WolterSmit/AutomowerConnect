import Foundation
import SwiftUI
import AuthenticationServices
import OSLog

let logger = Logger(subsystem: "com.topdesk.AutomowerConnect", category: "authenticate")

public class AutomowerConnect {
        
    let applicationKey: String
    let clientSecret: String

    var token: Token?
    
    public init(applicationKey: String, clientSecret: String) {
        self.applicationKey = applicationKey
        self.clientSecret = clientSecret
    }
    
    func getToken(for request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200, 201: break
            case 400: throw AutomowerConnectError.badRequest
            case 401: throw AutomowerConnectError.unauthorized
            default:
                throw AutomowerConnectError.invalidStatusCode(httpResponse.statusCode)
            }
        }
                
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            token = Token(from: tokenResponse)
        } catch {
            let string = String(data: data, encoding: .utf8) ?? "<none>"
            throw AutomowerConnectError.cannotDecode(string, error)
        }
    }
    
    public func authenticateClientCredentials() async throws {
        let request = try Endpoint.tokenClientCredentials(clientId: applicationKey, clientSecret: clientSecret)
        
        try await getToken(for: request)
        
    }
    
    public func startAuthentication(session: WebAuthenticationSession) async throws {
        let authenticateURL = try Endpoint.authenticate(clientId: applicationKey, redirect: Endpoint.redirectUri).url()
        
        print("Starting authentication session")
        
        let urlWithToken = try await session.authenticate(using: authenticateURL, callbackURLScheme: Endpoint.redirectSchema)
        
        print("Received response from authentication service")
        
        guard let queryItems = URLComponents(string: urlWithToken.absoluteString)?.queryItems,
              let codeProperty = queryItems.filter({ $0.name == "code" }).first?.value,
              let stateProperty = queryItems.filter({ $0.name == "state" }).first?.value else {
            throw AutomowerConnectError.receivedInvalidResponse
        }
        
        let request = try Endpoint.tokenAuthorizationGrant(clientId: applicationKey, clientSecret: clientSecret, code: codeProperty, redirectURI: Endpoint.redirectUri, state: stateProperty)
        
        try await getToken(for: request)
    }
    
    public func getMowers() async throws -> [String] {
        let data = try await get(.mowers)
        let mowers = try JSONDecoder().decode(MowersDTO.self, from: data)
        
        return mowers.data.map {
            $0.attributes.system.name
        }
    }
    
    func get(_ endpoint: Endpoint) async throws -> Data {
        guard let token = token else {
            throw AutomowerConnectError.notLoggedIn
        }
        var request = URLRequest(url: try endpoint.url())
        
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("husqvarna", forHTTPHeaderField: "Authorization-Provider")
        request.addValue(applicationKey, forHTTPHeaderField: "X-Api-Key")
                
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200, 201: break
            case 400: throw AutomowerConnectError.badRequest
            case 401: throw AutomowerConnectError.unauthorized
            default:
                throw AutomowerConnectError.invalidStatusCode(httpResponse.statusCode)
            }
        }
        
        print(String(data: data, encoding: .utf8) ?? "<none>")
        
        return data
    }
    
}

//{
//  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...xwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
//  "scope": "iam:read",
//  "expires_in": 3600,
//  "refresh_token": "55021ad9-6451-48eb-5ad2-1c2b53b7dca9",
//  "provider": "husqvarna",
//  "user_id": "610b0aee-3d4f-3ac6-bd8e-786deafa94ce",
//  "token_type": "Bearer"
//}

struct Token {
    let accessToken: String
    let refreshToken: String?
    let validUntil: Date
    
    init(from token: TokenResponse) {
        accessToken = token.access_token
        refreshToken = token.refresh_token
        validUntil = Date().addingTimeInterval(TimeInterval(token.expires_in))
    }
}

struct TokenResponse: Decodable {
    var access_token: String
    var scope: String
    var expires_in: Int
    var refresh_token: String?
    var provider: String
    var user_id: String
    var token_type: String
}

struct Endpoint {
    
    enum API {
        case authentication
        case husqvarna
        
        var components: URLComponents {
            var parts = URLComponents()
            switch self {
            case .authentication:
                parts.scheme = "https"
                parts.host = "api.authentication.husqvarnagroup.dev"
            case .husqvarna:
                parts.scheme = "https"
                parts.host = "api.amc.husqvarna.dev"
            }
            return parts
        }
    }
    
    var path: String
    var queryItems: [URLQueryItem] = []
    var api: API
    
    func url() throws -> URL {
        var components = api.components
        components.path = path

        if queryItems.count > 0 {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            preconditionFailure(
                "Invalid URL components: \(components)"
            )
        }
        
        return url
    }
    
    static let redirectSchema = "automower"
    static var redirectUri: String { "\(redirectSchema)://" }
    
    //"https://api.authentication.husqvarnagroup.dev/v1/oauth2/authorize?client_id=<APP KEY>&redirect_uri=<REDIRECT_URI>"
    static func authenticate(clientId: String, redirect: String) -> Self {
        return Endpoint(
            path: "/v1/oauth2/authorize",
            queryItems: [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: redirect)
            ],
            api: .authentication
        )
    }
    
    static var token: Self {
        return Endpoint(path: "/v1/oauth2/token", api: .authentication)
    }
    
    
//    curl --location --request POST 'https://api.authentication.husqvarnagroup.dev/v1/oauth2/token' \
//    --header 'Content-Type: application/x-www-form-urlencoded' \
//    --data-urlencode 'client_id=<APP KEY>' \
//    --data-urlencode 'client_secret=<CLIENT_SECRET>' \
//    --data-urlencode 'grant_type=client_credentials'
    static func tokenClientCredentials(clientId: String, clientSecret: String) throws -> URLRequest {
        var url = URLRequest(url: try Endpoint.token.url())
        let data = "grant_type=client_credentials&client_id=\(clientId)&client_secret=\(clientSecret)"
        
        url.httpMethod = "POST"
        url.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        url.httpBody = Data(data.utf8)
        
        return url
    }
    
//     curl -X POST -d \
//    --url "https://api.authentication.husqvarnagroup.dev/v1/oauth2/token" \
//    --header "content-type: application/x-www-form-urlencoded" \
//    --data "grant_type=authorization_code&client_id=<APP KEY>&client_secret=<CLIENT_SECRET>&code=<AUTHORIZATION_CODE>&redirect_uri=<REDIRECT_URI>&state=<STATE>"
    static func tokenAuthorizationGrant(clientId: String, clientSecret: String, code: String, redirectURI: String, state: String) throws  -> URLRequest {
        var url = URLRequest(url: try Endpoint.token.url())
        let data = "grant_type=authorization_code&client_id=\(clientId)&client_secret=\(clientSecret)&code=\(code)&redirect_uri=\(redirectURI)&state=\(state)"
        
        url.httpMethod = "POST"
        url.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        url.httpBody = Data(data.utf8)
        
        return url
    }
    
    static let mowers = Endpoint(path: "/v1/mowers", api: .husqvarna)
}


public enum AutomowerConnectError: Error {
    case generalError(Error)
    case invalidURL(path: String)
    case receivedInvalidResponse
    case badRequest
    case unauthorized
    case invalidStatusCode(Int)
    case cannotDecode(String, Error)
    case cannotFindBundle
    case notLoggedIn
    
    
    var localizedDescription: String {
        switch self {
        case .generalError(let error): return "general error: \(error.localizedDescription)"
        case .invalidURL(path: let path): return "invalid URL for path \(path)"
        case .receivedInvalidResponse: return "received invalid response"
        case .badRequest: return "bad request"
        case .unauthorized: return "unauthorized"
        case .invalidStatusCode(let code): return "invalid status code \(code)"
        case .cannotDecode(let string, let error): return "cannot decode\n\(string)\n\(error.localizedDescription)"
        case .cannotFindBundle: return "cannot find bundle for credentials"
        case .notLoggedIn: return "not logged in. We do not have a token"
        }
    }
}
