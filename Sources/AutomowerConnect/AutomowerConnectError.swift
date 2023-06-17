//
//  File.swift
//  
//
//  Created by WolterS on 17/06/2023.
//

import Foundation


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
