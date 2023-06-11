import Foundation

public class AutomowerConnect {
    
    public enum LoginState {
        case readyForLogin
        case failed(error: AutomowerConnectError)
        case loggenIn
    }
    
    private let applicationKey: String
    private let clientId: String
    
    public init(applicationKey: String, clientId: String) {
        self.applicationKey = applicationKey
        self.clientId = clientId
    }
    
}

//{
//  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...xwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
//  "scope": "iam:read",
//  "expires_in": 3600,
//  "provider": "husqvarna",
//  "user_id": "610b0aee-3d4f-3ac6-bd8e-786deafa94ce",
//  "token_type": "Bearer"
//}
struct TokenResponse: Decodable {
    var access_token: String
    var scope: String
    var expires_in: Int
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
    
    //"<REDIRECT_URI>?code=<AUTHORIZATION_CODE>&state=<STATE>"
    static var token: Self {
        return Endpoint(path: "/v1/oauth2/token", api: .authentication)
    }
    
//     curl -X POST -d \
//    --url "https://api.authentication.husqvarnagroup.dev/v1/oauth2/token" \
//    --header "content-type: application/x-www-form-urlencoded" \
//    --data "grant_type=authorization_code&client_id=<APP KEY>&client_secret=<CLIENT_SECRET>&code=<AUTHORIZATION_CODE>&redirect_uri=<REDIRECT_URI>&state=<STATE>"
    static func tokenRequest(clientId: String, code: String, redirectURI: String, state: String) throws  -> URLRequest {
        var url = URLRequest(url: try Endpoint.token.url())
        let data = "grant_type=authorization_code&client_id=\(clientId)&code=\(code)&redirect_uri=\(redirectURI)&state=\(state)"
        
        url.httpMethod = "POST";
        url.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        url.httpBody = Data(data.utf8)
        
        return url
    }
    
}


public enum AutomowerConnectError: Error {
    case generalError(Error)
    case invalidURL(path: String)
    
    var localizedDescription: String {
        switch self {
        case .generalError(let error): return "general error: \(error)"
        case .invalidURL(path: let path): return "invalid URL for path \(path)"
        }
    }
}
