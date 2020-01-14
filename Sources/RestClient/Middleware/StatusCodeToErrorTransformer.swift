//
//  StatusCodeToErrorTransformer.swift
//  RestClient
//
//  Created by Florian Schwehn on 01.02.19.
//

import Vapor

public struct StatusCodeToErrorTransformer: RestClientMiddleware {
    
    public init() {}
    
    public func respond(to request: ClientRequest, chainingTo next: RestClientResponder) -> EventLoopFuture<ClientResponse> {
        return next.respond(to: request).flatMapResult { (response) -> Result<ClientResponse, Error> in
            guard response.status.code < 400 else {
                return .failure(ClientRequestError(request: request, response: response, underlyingError: nil))
            }
            
            return .success(response)
        }
    }
    
}
