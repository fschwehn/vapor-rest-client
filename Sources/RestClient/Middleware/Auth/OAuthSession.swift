//
//  OAuthSession.swift
//  RestClient
//
//  Created by Florian Schwehn on 10.02.19.
//

import Vapor

public protocol OAuthSession: class {
    
    var scope: String { get }
    var accessToken: String { get set }
    var expiresAt: Date { get set }
    
    func tokenRequestBody(clientId: String, clientSecret: String) -> [String:String]
    func update(with content: Vapor.ContentContainer, on eventLoop: EventLoop) -> EventLoopFuture<Self>
//    func saveState(on container: Container) -> EventLoopFuture<Self>
    
}
