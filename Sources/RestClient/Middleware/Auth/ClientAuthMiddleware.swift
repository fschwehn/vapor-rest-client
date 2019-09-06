//
//  ClientAuthMiddleware.swift
//  RestClient
//
//  Created by Florian Schwehn on 08.02.19.
//

import Vapor

enum ClientAuthMiddlewareError: Debuggable {
    
    var identifier: String {
        switch self {
        case .authenticationFailedAfterTooManyRetrials(_):
            return "ClientAuthMiddlewareError.authenticationFailedAfterTooManyRetrials"
        case .tokenRefreshFailed(_, _):
            return "ClientAuthMiddlewareError.tokenRefreshFailed"
        }
    }
    
    var reason: String {
        switch self {
        case .authenticationFailedAfterTooManyRetrials(let url):
            return "Authentication failed after too many retrials (\(url))"
        case .tokenRefreshFailed(let url, let response):
            let reason = response.description
            return "Token refresh failed calling URL '\(url)':\n\t\(reason.split(separator: "\n").joined(separator: "\n\t"))"
        }
    }
    
    case authenticationFailedAfterTooManyRetrials(url: URLRepresentable)
    case tokenRefreshFailed(url: URLRepresentable, response: Response)
    
}

open class ClientAuthMiddleware<Session>: Middleware where Session: OAuthSession {

    public let container: Container
    private(set) var accessTokenUrl: URLRepresentable
    private(set) var session: Session
    
    private let clientId: String
    private let clientSecret: String
    private var refreshTokenFuture: EventLoopFuture<String>?
    
    public init(container: Container,
                clientId: String,
                clientSecret: String,
                accessTokenUrl: URLRepresentable,
                session: Session)
    {
        self.container = container
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.accessTokenUrl = accessTokenUrl
        self.session = session
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        return try token(container: request)
            .flatMap({ (token) -> EventLoopFuture<Response> in
                return try self.respond(to: request, token: token, chainingTo: next, trialsLeft: 3)
            })
    }
    
    private func token(container: Container) throws -> EventLoopFuture<String> {
        if session.expiresAt < Date() {
            refreshTokenFuture = try refreshToken(container: container)
        }
        return refreshTokenFuture ?? container.eventLoop.future(session.accessToken)
    }
    
    private func respond(to request: Request, token: String, chainingTo next: Responder, trialsLeft: Int) throws -> EventLoopFuture<Response> {
        // check for max trials
        if trialsLeft == 0 {
            throw ClientAuthMiddlewareError.authenticationFailedAfterTooManyRetrials(url: request.http.url)
        }
        
        // set auth header
        request.http.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token)")
        
        // send request
        return try next.respond(to: request)
            .flatMap({ (res) -> EventLoopFuture<Response> in
                // handle unauthorized status
                if res.http.status == .unauthorized {
                    return try self.refreshToken(container: request)
                        .flatMap({ (token) -> EventLoopFuture<Response> in
                            return try self.respond(to: request, token: token, chainingTo: next, trialsLeft: trialsLeft - 1)
                        })
                }
                
                return request.eventLoop.future(res)
            })
    }
    
    private func refreshToken(container: Container) throws -> EventLoopFuture<String> {
        if let pendingRefresh = refreshTokenFuture {
            return pendingRefresh
        }
        
        let newRefreshTokenFuture = try container.client()
            .post(accessTokenUrl, beforeSend: { (req) in
                let body = session.tokenRequestBody(clientId: clientId, clientSecret: clientSecret)
                try req.content.encode(body, as: .formData)
            })
            // validate response status
            .flatMap({ (res) -> EventLoopFuture<String> in
                guard res.http.status == .ok else {
                    throw ClientAuthMiddlewareError.tokenRefreshFailed(url: self.accessTokenUrl, response: res)
                }
                
                return try self.session
                    .update(with: res.content, on: self.container)
                    .map({ $0.accessToken })
            })
            .always({
                self.refreshTokenFuture = nil
            })
        
        refreshTokenFuture = newRefreshTokenFuture
        
        return newRefreshTokenFuture
    }
    
}
