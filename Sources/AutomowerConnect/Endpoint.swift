//
//  File.swift
//  
//
//  Created by WolterS on 17/06/2023.
//

import Foundation

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
