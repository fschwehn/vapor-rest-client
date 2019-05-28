//
//  RequestLogger.swift
//  RestClient
//
//  Created by Florian Schwehn on 06.02.19.
//

import Vapor

public struct RequestLogger: Middleware {
    
    let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        return try next.respond(to: request)
            .do({ res in
                self.logger.verbose("Status \(res.http.status.code) [\(request.http.method):\(request.http.url)]")
            })
    }
    
}
