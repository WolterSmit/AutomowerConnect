import Foundation
import SwiftUI
import AuthenticationServices

///  A class that allows connection to the API of Gardena and Husqvarna robot mowers.
///
///  This class is instantiated with an application key and secret that should be obtained in the developer portal of the API. Next, a call to
///  either ``authenticateClientCredentials()`` or ``startAuthentication(session:)`` will authenticate to the API.
///  When successful, a token will be received and stored in this class.
///
///  After successful authentication, calls to the actual API can be made e.g., ``getMowers()``
///
///
///  ```swift
///     let api = AutomowerConnect(applicationKey: "<key>", clientSecret: "<secret>")
///     do {
///         try await api.authenticateClientCredentials()
///         mowers = try await api.getMowers()
///     } catch {
///         print("Had an error: \(error)")
///     }
///  ```
///
public class AutomowerConnect {
        
    /// The application key as defined in the developer portal.
    let applicationKey: String
    /// The application secret as defined in the developer portal.
    let clientSecret: String

    /// The token used for authenticating to the API's. It is an optonal value. After successful authentication,
    /// the recevieed token will be stored here.
    var token: Token?
    
    
    /// The initializer for the class. Provide with the application key and secret as obtained from the developer portal.
    /// - Parameters:
    ///   - applicationKey: The application key from the developer portal
    ///   - clientSecret: The application secret from the developer portal
    public init(applicationKey: String, clientSecret: String) {
        self.applicationKey = applicationKey
        self.clientSecret = clientSecret
    }
    
    /// Requests the API for a token that can be used for further authentication to the API. The token will be stored
    /// in the ``token`` property.
    /// - Parameter request: A ``URLRequest`` used to request the token.
    /// - Throws: ``AutomowerConnectError.badRequest`` if the API responds with status code 400. ``AutomowerConnectError.unauthorized`` if the API responds with 401. ``AutomowerConnectError.invalidStatusCode`` for any other status code but 200 or 201.
    ///
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
        
        // Try to decode the response.
                
        do {
            let tokenResponse = try JSONDecoder().decode(TokenDTO.self, from: data)
            token = Token(from: tokenResponse)
        } catch {
            let string = String(data: data, encoding: .utf8) ?? "<none>"
            throw AutomowerConnectError.cannotDecode(string, error)
        }
    }
    
    /// Authenticate to the API through a Client Credentials Grant.
    ///
    /// This is as if we log in as a user with a password. This only works for a specific user. For a workflow where the user can identify themself,
    /// use ``startAuthentication(session:)``.
    /// - Throws:An ``AutomowerConnectError`` in case of errors.
    public func authenticateClientCredentials() async throws {
        let request = try Endpoint.tokenClientCredentials(clientId: applicationKey, clientSecret: clientSecret)
        
        try await getToken(for: request)
        
    }
    
    /// Authenticate to the API through a Authorization Grant.
    ///
    /// This will start a WebAuthentication Session asking for user credentials. When successful, a token will be received and stored. This will allow
    /// further calls to the API. When unsuccssful, an error will be thrown.
    ///
    /// Use ``authenticateClientCredentials()`` to log in with a client credential grant as if we are a specfic user.
    /// - Parameter session: A reference to a `WebAuthenticationSession` necessary to start the authentication.
    /// - Throws:An ``AutomowerConnectError`` in case of errors.
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
    
    /// Ask for a list of mowers. We need to be authenticated first.
    /// - Returns: A `[String]` with the names of the mowers.
    /// - Throws: An ``AutomowerConnectError`` when something went wrong. Specifically
    /// `AutomowerConnectError.notLoggedIn` when there is no token available. This is typically
    /// if we are not authenticated yet.
    public func getMowers() async throws -> [String] {
        let data = try await get(.mowers)
        let mowers = try JSONDecoder().decode(MowersDTO.self, from: data)
        
        return mowers.data.map {
            $0.attributes.system.name
        }
    }
    
    
    /// Execute a request as defined with an endpoint and return generic data.
    ///
    /// A `URLRequest` will be built from the ``Endpoint``. The authentication fields will be added
    /// - Parameter endpoint: The ``Endpoint`` describing the API endpoint.
    /// - Returns: The `Data` returned from the API.
    /// - Throws: An ``AutomwerConnectError`` when something went wrong. Specifically
    /// ``AutomowerConnectError.notLoggedIn`` when there is no token available. This is typically
    /// if we are not authenticated yet.
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

