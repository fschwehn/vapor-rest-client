//
//  AuthorizationCodeOAuthSession.swift
//  RestClient
//
//  Created by Florian Schwehn on 10.02.19.
//

import Vapor

//public protocol AuthorizationCodeOAuthSession: OAuthSession {
//    var refreshToken: String { get set }
//}
//
//internal struct AuthorizationCodeResponseBody: Content {
//    var access_token: String
//    var expires_in: Int
//    var token_type: String
//    var scope: String
//    var refresh_token: String
//}
//
//public extension AuthorizationCodeOAuthSession {
//    
//    func tokenRequestBody(clientId: String, clientSecret: String) -> [String:String] {
//        return [
//            "client_id": clientId,
//            "client_secret": clientSecret,
//            "grant_type": "refresh_token",
//            "refresh_token": refreshToken,
//            "scope": scope,
//        ]
//    }
//    
//    func update(with content: ContentContainer<Response>, on container: Container) throws -> EventLoopFuture<Self> {
//        return try content.decode(AuthorizationCodeResponseBody.self)
//            .flatMap({ (body) -> EventLoopFuture<Self> in
//                let expirationInterval = Double(body.expires_in) * 0.95
//                
//                self.accessToken = body.access_token
//                self.refreshToken = body.refresh_token
//                self.expiresAt = Date(timeIntervalSinceNow: expirationInterval)
//                
//                return self.saveState(on: container)
//            })
//    }
//    
//}
