//
//  BasicAuthorization+RestClientMiddleware.swift
//  App
//
//  Created by Florian Schwehn on 15.01.20.
//

import Vapor

extension BasicAuthorization: RestClientMiddleware {
    
    public func respond(to request: ClientRequest, chainingTo next: RestClientResponder) -> EventLoopFuture<ClientResponse> {
        var request = request
        request.headers.basicAuthorization = self
        return next.respond(to: request)
    }
    
}
