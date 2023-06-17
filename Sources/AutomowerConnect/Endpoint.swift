//
//  File.swift
//  
//
//  Created by WolterS on 17/06/2023.
//

import Foundation

/// Describes the various endpoints that the Automoiwer API understands.
struct Endpoint {
    
    /// Describes the API that needs to be used for this endpoint.
    enum API {
        /// Use the authentication API
        case authentication
        /// Use the Husqvarna Automower API, typically after authentication.
        case husqvarna
        
        /// Give the `URLComponents` for the selected API. This includes `schema` and `host`.
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
    
    /// The path for the URL
    var path: String
    /// Optional query items to be appended to the URL
    var queryItems: [URLQueryItem] = []
    /// The API to use.
    var api: API
    
    /// Build a URL for the ``Endpoint``.
    /// - Returns: A `URL` built from all the components of the ``Endpoint``
    func url() throws -> URL {
        var components = api.components
        components.path = path

        if queryItems.count > 0 {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw AutomowerConnectError.invalidURL(path: path)
        }
        
        return url
    }
    
    /// The schema to use for the redirect in the Authorization Code Grant.
    static let redirectSchema = "automower"
    /// The URI to use for the redirect in the Authorization Code Grant.
    static var redirectUri: String { "\(redirectSchema)://" }
    
    // "https://api.authentication.husqvarnagroup.dev/v1/oauth2/authorize?client_id=<APP KEY>&redirect_uri=<REDIRECT_URI>"
    /// An endpoint for authentication in the Authorization Code Grant
    /// - Parameters:
    ///   - clientId: The client ID to use
    ///   - redirect: The redirect URI to use. Typically ``redirectUri``.
    /// - Returns: The ``Endpoint``
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
    
    /// An endpoint for getting a token for any authorization scheme.
    static var token: Self {
        return Endpoint(path: "/v1/oauth2/token", api: .authentication)
    }
    
    
//    curl --location --request POST 'https://api.authentication.husqvarnagroup.dev/v1/oauth2/token' \
//    --header 'Content-Type: application/x-www-form-urlencoded' \
//    --data-urlencode 'client_id=<APP KEY>' \
//    --data-urlencode 'client_secret=<CLIENT_SECRET>' \
    //    --data-urlencode 'grant_type=client_credentials'
    /// An endpoint for getting a token in the Client Credetials Gtrant.
    /// - Parameters:
    ///   - clientId: The application key as obtained from the developer portal,
    ///   - clientSecret: The application secret as obtained from the developer portal.
    /// - Returns: The ``Endpoint``
    /// - Throws: ``AutomwerConnectError.invalidURL`` when no valid URL can be built.
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
    /// An endpoint for getting a Authorization Code Grant.
    /// - Parameters:
    ///   - clientId: The application key as obtained from the developer portal,
    ///   - clientSecret: The application secret as obtained from the developer portal.
    ///   - code: The code as received from the web authentication session.
    ///   - redirectURI: The redirect URI as used in the web authentication session.
    ///   - state: The state as received from the web authentication session.
    /// - Returns: The ``Endpoint``
    /// - Throws: ``AutomwerConnectError.invalidURL`` when no valid URL can be built.
    static func tokenAuthorizationGrant(clientId: String, clientSecret: String, code: String, redirectURI: String, state: String) throws  -> URLRequest {
        var url = URLRequest(url: try Endpoint.token.url())
        let data = "grant_type=authorization_code&client_id=\(clientId)&client_secret=\(clientSecret)&code=\(code)&redirect_uri=\(redirectURI)&state=\(state)"
        
        url.httpMethod = "POST"
        url.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        url.httpBody = Data(data.utf8)
        
        return url
    }
    
    /// An endpoint for receiving a list of mowers and their status.
    static let mowers = Endpoint(path: "/v1/mowers", api: .husqvarna)
}
