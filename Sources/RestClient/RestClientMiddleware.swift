//
//  File.swift
//  
//
//  Created by Florian Schwehn on 13.01.20.
//

import Vapor

public protocol RestClientResponder {
    func respond(to request: ClientRequest) -> EventLoopFuture<ClientResponse>
}

public protocol RestClientMiddleware {
    func respond(to request: ClientRequest, chainingTo next: RestClientResponder) -> EventLoopFuture<ClientResponse>
}

extension Array where Element == RestClientMiddleware {
    public func makeResponder(chainingTo responder: RestClientResponder) -> RestClientResponder {
        var responder = responder
        for middleware in reversed() {
            responder = middleware.makeResponder(chainingTo: responder)
        }
        return responder
    }
}

public extension RestClientMiddleware {
    func makeResponder(chainingTo responder: RestClientResponder) -> RestClientResponder {
        return ClientHTTPMiddlewareResponder(middleware: self, responder: responder)
    }
}

private struct ClientHTTPMiddlewareResponder: RestClientResponder {
    var middleware: RestClientMiddleware
    var responder: RestClientResponder
    
    init(middleware: RestClientMiddleware, responder: RestClientResponder) {
        self.middleware = middleware
        self.responder = responder
    }
    
    func respond(to request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return self.middleware.respond(to: request, chainingTo: self.responder)
    }
}
