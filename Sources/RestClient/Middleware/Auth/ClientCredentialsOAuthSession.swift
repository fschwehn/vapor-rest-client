//
//  ClientCredentialsOAuthSession.swift
//  RestClient
//
//  Created by Florian Schwehn on 10.02.19.
//

import Vapor

public protocol ClientCredentialsOAuthSession: OAuthSession {}

internal struct ClientCredentialsResponseBody: Content {
    var access_token: String
    var expires_in: Int
    var token_type: String
}

extension ClientCredentialsOAuthSession {
    
    public func tokenRequestBody(clientId: String, clientSecret: String) -> [String:String] {
        return [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "client_credentials",
            "scope": scope,
        ]
    }
    
    public func update(with content: ContentContainer<Response>, on container: Container) throws -> EventLoopFuture<Self> {
        return try content.decode(ClientCredentialsResponseBody.self)
            .flatMap({ (body) -> EventLoopFuture<Self> in
                let expirationInterval = Double(body.expires_in) * 0.95
                
                self.accessToken = body.access_token
                self.expiresAt = Date(timeIntervalSinceNow: expirationInterval)
                
                return self.saveState(on: container)
            })
    }
    
}
