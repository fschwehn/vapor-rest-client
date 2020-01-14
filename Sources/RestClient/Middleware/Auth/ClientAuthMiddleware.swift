//
//  ClientAuthMiddleware.swift
//  RestClient
//
//  Created by Florian Schwehn on 08.02.19.
//

import Vapor

public enum ClientAuthMiddlewareError: LocalizedError {
    
//    public var identifier: String {
//        switch self {
//        case .authenticationFailedAfterTooManyRetrials(_):
//            return "ClientAuthMiddlewareError.authenticationFailedAfterTooManyRetrials"
//        case .tokenRefreshFailed(_, _):
//            return "ClientAuthMiddlewareError.tokenRefreshFailed"
//        }
//    }
    
//    public var reason: String {
//        switch self {
//        case .authenticationFailedAfterTooManyRetrials(let url):
//            return "Authentication failed after too many retrials (\(url))"
//        case .tokenRefreshFailed(let url, let response):
//            let reason = response.description
//            return "Token refresh failed calling URL '\(url)':\n\t\(reason.split(separator: "\n").joined(separator: "\n\t"))"
//        }
//    }
    
    case authenticationFailedAfterTooManyRetrials(url: URI)
    case tokenRefreshFailed(url: URI, response: ClientResponse)
    
}

open class ClientAuthMiddleware<Session>: RestClientMiddleware where Session: OAuthSession {

    public let client: Client
    public let clientId: String
    public let clientSecret: String
    public let eventLoop: EventLoop
    
    private(set) var accessTokenUrl: URI
    private(set) var session: Session
    
    private var refreshTokenPromise: EventLoopPromise<String>?
    
    public init(client: Client,
                clientId: String,
                clientSecret: String,
                accessTokenUrl: URI,
                session: Session,
                eventLoop: EventLoop)
    {
        self.client = client
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.accessTokenUrl = accessTokenUrl
        self.session = session
        self.eventLoop = eventLoop
    }
    
    open func respond(to request: ClientRequest, chainingTo next: RestClientResponder) -> EventLoopFuture<ClientResponse> {
        return token().flatMap { token in
            return self.respond(to: request, token: token, chainingTo: next, trialsLeft: 3)
        }
    }
    
    private func token() -> EventLoopFuture<String> {
        guard session.expiresAt > Date() else {
            return refreshToken()
        }
        
        return refreshTokenPromise?.futureResult ?? eventLoop.future(session.accessToken)
    }
    
    private func respond(to request: ClientRequest, token: String, chainingTo next: RestClientResponder, trialsLeft: Int) -> EventLoopFuture<ClientResponse> {
        // check for max trials
        guard trialsLeft > 0 else {
            return eventLoop.makeFailedFuture(ClientAuthMiddlewareError.authenticationFailedAfterTooManyRetrials(url: request.url))
        }
        
        var request = request
        
        // set auth header
        request.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token)")
        
        // send request
        return next.respond(to: request)
            .flatMap({ response -> EventLoopFuture<ClientResponse> in
                // handle unauthorized status
                if response.status == .unauthorized {
                    return self.refreshToken().flatMap { token in
                        self.respond(to: request, token: token, chainingTo: next, trialsLeft: trialsLeft - 1)
                    }
                }
                
                return self.eventLoop.future(response)
            })
    }
    
    private func refreshToken() -> EventLoopFuture<String> {
        switch refreshTokenPromise {
        case .some(let existing):
            return existing.futureResult
        default:
            let newRefreshTokenPromise = eventLoop.makePromise(of: String.self)
            refreshTokenPromise = newRefreshTokenPromise
            
            client.post(accessTokenUrl, beforeSend: { (req) in
                let body = session.tokenRequestBody(clientId: clientId, clientSecret: clientSecret)
                try req.content.encode(body, as: .formData)
            }).whenComplete { result in
                switch result {
                case .failure(let error):
                    newRefreshTokenPromise.fail(error)
                    break
                case .success(let response):
                    guard response.status == .ok else {
                        newRefreshTokenPromise.fail(ClientAuthMiddlewareError.tokenRefreshFailed(url: self.accessTokenUrl, response: response))
                        return
                    }
                    
                    self.session.update(with: response.content, on: self.eventLoop).whenComplete { result in
                        switch result {
                        case .failure(let error):
                            newRefreshTokenPromise.fail(error)
                        case .success(let session):
                            newRefreshTokenPromise.succeed(session.accessToken)
                        }
                    }
                }
            }
            
            newRefreshTokenPromise.futureResult.whenComplete { _ in self.refreshTokenPromise = nil }
            
            return newRefreshTokenPromise.futureResult
        }
    }
    
}
