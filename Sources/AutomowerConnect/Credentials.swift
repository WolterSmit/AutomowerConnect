//
//  File.swift
//  
//
//  Created by WolterS on 17/06/2023.
//

import Foundation

public struct Credentials: Codable {
    public let applicationKey: String
    public let applicationSecret: String
    
    public init(key: String, secret: String) {
        applicationKey = key
        applicationSecret = secret
    }
    
    public static func loadFromBundle() throws -> Self {
        guard let path = Bundle.main.url(forResource: "credentials", withExtension: "json") else {
            throw AutomowerConnectError.cannotFindBundle
        }
        
        let data = try Data(contentsOf: path)
        let credentials = try JSONDecoder().decode(Credentials.self, from: data)
        
        return credentials
    }
    
    public func prettyPrintJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(self),
           let string = String(bytes: data, encoding: .utf8) {
               print(string)
        } else {
            print("Could not format")
        }
        
    }
}

