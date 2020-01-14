//
//  JWTAuthMiddleware.swift
//  RestClient
//
//  Created by Florian Schwehn on 08.02.19.
//

import Vapor

//public protocol JWTAuthMiddlewareTokenProvider {
//    
//    func createNewSignedJWT(issuedAt: Date, expiringAt: Date) throws -> String
//    
//}
//
//open class JWTAuthMiddleware: Middleware {
//
//    public let container: Container
//    public let tokenExpirationInterval: TimeInterval
//    public let tokenProvider: JWTAuthMiddlewareTokenProvider
//    
//    private var tokenExpiresAt: Date = .distantPast
//    private var tokenString: String = ""
//
//    public init(container: Container, tokenExpirationInterval: TimeInterval = 3600, tokenProvider: JWTAuthMiddlewareTokenProvider)
//    {
//        self.container = container
//        self.tokenExpirationInterval = tokenExpirationInterval
//        self.tokenProvider = tokenProvider
//    }
//
//    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
//        return try token()
//            .flatMap({ token -> EventLoopFuture<Response> in
//                return try self.respond(to: request, token: token, chainingTo: next, trialsLeft: 3)
//            })
//    }
//
//    private func token() throws -> EventLoopFuture<String> {
//        return tokenExpiresAt <= Date()
//            ? try refreshToken()
//            : container.eventLoop.future(self.tokenString)
//    }
//
//    private func respond(to request: Request, token: String, chainingTo next: Responder, trialsLeft: Int) throws -> EventLoopFuture<Response> {
//        // check for max trials
//        if trialsLeft == 0 {
//            throw VaporError(identifier: "JWTAuthMiddleware.authenticationFailedAfterTooManyRetrials", reason: "authentication failed after too many retrials")
//        }
//        
//        // set auth header
//        request.http.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token)")
//        
//        // send request
//        return try next.respond(to: request)
//            .flatMap({ res -> Future<Response> in
//                // handle unauthorized status
//                if res.http.status == .unauthorized {
//                    return try self.refreshToken()
//                        .flatMap({ token -> EventLoopFuture<Response> in
//                            return try self.respond(to: request, token: token, chainingTo: next, trialsLeft: trialsLeft - 1)
//                        })
//                }
//
//                return request.eventLoop.future(res)
//            })
//    }
//
//    private func refreshToken() throws -> EventLoopFuture<String> {
//        let promise = container.eventLoop.newPromise(String.self)
//        
//        container.eventLoop.execute {
//            do {
//                // create new token
//                let issuedAt = Date()
//                let tokenExpiresAt = issuedAt.addingTimeInterval(self.tokenExpirationInterval * 0.95)
//                let tokenString = try self.tokenProvider.createNewSignedJWT(issuedAt: issuedAt, expiringAt: tokenExpiresAt)
//
//                // update state
//                self.tokenString = tokenString
//                self.tokenExpiresAt = tokenExpiresAt
//                
//                promise.succeed(result: tokenString)
//            }
//            catch {
//                promise.fail(error: error)
//            }
//        }
//
//        return promise.futureResult
//    }
//    
//}
