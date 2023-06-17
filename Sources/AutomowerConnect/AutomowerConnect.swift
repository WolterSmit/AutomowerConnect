import Foundation
import SwiftUI
import AuthenticationServices

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
            let tokenResponse = try JSONDecoder().decode(TokenDTO.self, from: data)
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
    
    init(from token: TokenDTO) {
        accessToken = token.access_token
        refreshToken = token.refresh_token
        validUntil = Date().addingTimeInterval(TimeInterval(token.expires_in))
    }
}

struct TokenDTO: Decodable {
    var access_token: String
    var scope: String
    var expires_in: Int
    var refresh_token: String?
    var provider: String
    var user_id: String
    var token_type: String
}

