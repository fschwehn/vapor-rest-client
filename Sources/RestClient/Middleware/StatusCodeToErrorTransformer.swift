//
//  StatusCodeToErrorTransformer.swift
//  RestClient
//
//  Created by Florian Schwehn on 01.02.19.
//

import Vapor

public struct StatusCodeToErrorTransformer: Middleware {
    
    public init() {}
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        return try next.respond(to: request).flatMap({ response -> EventLoopFuture<Response> in
            if response.http.status.code < 400 {
                return request.eventLoop.future(response)
            }
            
            throw RequestError(request: request, response: response, underlyingError: nil)
        })
    }
    
}
