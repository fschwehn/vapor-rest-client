//
//  RequestError.swift
//  RestClient
//
//  Created by Florian Schwehn on 29.04.19.
//

import Vapor

public struct RequestError: Debuggable {
    
    public let request: Request
    public let response: Response?
    public let underlyingError: Error?
    public let message: String?
    
    public var status: HTTPStatus? {
        return response?.http.status
    }
    
    public static func wrap(_ error: Error, _ request: Request, _ response: Response? = nil) -> RequestError {
        switch error {
        case let error as RequestError:
            return error
        default:
            return RequestError(request: request, response: response, underlyingError: error)
        }
    }
    
    public init(request: Request, response: Response? = nil, underlyingError: Error? = nil) {
        self.request = request
        self.response = response
        self.underlyingError = underlyingError
        self.message = nil
    }
    
    public init(request: Request, response: Response? = nil, message: String) {
        self.request = request
        self.response = response
        self.underlyingError = nil
        self.message = message
    }
    
    public var identifier: String {
        return "\(RequestError.self): [\(request.http.method.string)]\(request.http.url)"
    }
    
    public var reason: String {
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
