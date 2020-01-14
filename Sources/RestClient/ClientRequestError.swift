//
//  ClientRequestError.swift
//  RestClient
//
//  Created by Florian Schwehn on 29.04.19.
//

import Vapor

public struct ClientRequestError: LocalizedError {
    
    public let request: ClientRequest
    public let response: ClientResponse?
    public let underlyingError: Error?
    public let message: String?
    
    public var status: HTTPStatus? {
        return response?.status
    }
    
    public static func wrap(_ error: Error, _ request: ClientRequest, _ response: ClientResponse? = nil) -> ClientRequestError {
        switch error {
        case let error as ClientRequestError:
            return error
        default:
            return ClientRequestError(request: request, response: response, underlyingError: error)
        }
    }
    
    public init(request: ClientRequest, response: ClientResponse? = nil, underlyingError: Error? = nil) {
        self.request = request
        self.response = response
        self.underlyingError = underlyingError
        self.message = nil
    }
    
    public init(request: ClientRequest, response: ClientResponse? = nil, message: String) {
        self.request = request
        self.response = response
        self.underlyingError = nil
        self.message = message
    }
    
    public var identifier: String {
        return "\(ClientRequestError.self): [\(request.method.string)]\(request.url)"
    }
    
    public var errorDescription: String? {
        var components = [String]()

        if let message = message {
            components.append(message)
        }
        
        if let underlyingError = underlyingError {
            components.append("Underlying error: \(underlyingError)")
        }
        
        components.append("Request: \(request)")
        
        if let response = response {
            components.append("Response: \(response)")
        }
        
        return components.joined(separator: "\n")
    }
    
}

public extension EventLoopFuture {
    
    @inlinable
    func mapErrorToClientRequestError(request: ClientRequest) -> EventLoopFuture<Value> {
        return flatMapErrorThrowing { (error: Error) -> Value in
            if let error = error as? ClientRequestError {
                throw error
            }
            
            throw ClientRequestError(request: request, response: nil, underlyingError: error)
        }
    }
    
}
