//
//  RestClient.swift
//  RestClient
//
//  Created by Florian Schwehn on 30.01.19.
//

import Vapor

public enum RestClientError: LocalizedError {
    case failedToResolveUrl(_: String)
    case failedToFormUrlFromComponents(_: URLComponents)
    
    public var errorDescription: String? {
        switch self {
        case .failedToResolveUrl(let url):
            return "Failed to form URLComponents from String '\(url)'"
        case .failedToFormUrlFromComponents(let components):
            return "Failed to form URL from URLComponents \(components)"
        }
    }
}

open class RestClient {
    
    public typealias Query = [String:String]
    
    /// Common prefix for all requests (e.g. "https://api.example.com/v1")
    public let hostUrl: URL
    
    public let eventLoop: EventLoop
    
    /// Middleware stack for request processing
    public var middleware = [RestClientMiddleware]()
    
    public var defaultDecoder: JSONDecoder = JSONDecoder()
    
    public var defaultEncoder: JSONEncoder = JSONEncoder()
    
    /// The client used to perform requests
    private let client: Client
    
    public init(client: Client, hostUrl: URL, eventLoop: EventLoop) {
        self.client = client
        self.hostUrl = hostUrl
        self.eventLoop = eventLoop
    }
    
    /// Resolves a given (incomplete) URL to `hostUrl`
    ///
    /// - Parameters:
    ///   - url: The URL to resolve
    ///   - query: optional query to append
    /// - Returns: resolved URI
    public func resolve(url: String, query: Query?) throws -> URI {
        let hostUrlString = hostUrl.absoluteString
        var urlString = url.starts(with: hostUrlString)
            ? url
            : hostUrlString + url
        
        if let query = query {
            guard var comps = URLComponents(string: urlString) else {
                throw RestClientError.failedToResolveUrl(urlString)
            }
            
            if !query.isEmpty {
                var queryItems = comps.queryItems ?? [URLQueryItem]()
                
                for (name, value) in query {
                    queryItems.append(URLQueryItem(name: name, value: value))
                }
                
                comps.queryItems = queryItems
                
                guard let parsedUrl = comps.url else {
                    throw RestClientError.failedToFormUrlFromComponents(comps)
                }
                
                urlString = parsedUrl.absoluteString
            }
        }
        
        return URI(string: urlString)
    }
    
    /// Kernel function - sends a `Request` down the responder chain of our `middleware`
    func send(_ req: ClientRequest) -> EventLoopFuture<ClientResponse> {
        let responder = middleware.makeResponder(chainingTo: self)
        let promise = eventLoop.makePromise(of: ClientResponse.self)
        
        eventLoop.execute {
            responder.respond(to: req).cascade(to: promise)
        }
        
        return promise.futureResult
    }
    
    /// Performs a request
    public func request(method: HTTPMethod = .GET,
                        url: String,
                        query: Query? = nil,
                        headers: HTTPHeaders = HTTPHeaders(),
                        body: ByteBuffer? = nil)
        -> EventLoopFuture<Void>
    {
        do {
            let uri = try resolve(url: url, query: query)
            let request = ClientRequest(method: method, url: uri, headers: headers, body: body)
            
            return send(request)
                .transform(to: ())
                .mapErrorToClientRequestError(request: request)
        }
        catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    /// Performs a request and decodes the JSON response body
    public func request<Return>(method: HTTPMethod = .GET,
                                url: String,
                                query: Query? = nil,
                                headers: HTTPHeaders = HTTPHeaders(),
                                decoder: JSONDecoder? = nil,
                                as: Return.Type)
        -> EventLoopFuture<Return>
        where Return: Decodable
    {
        return sendRequest(method: method, url: url, query: query, headers: headers)
            .flatMapThrowing({ try self.decodeResponseBody(request: $0, response: $1) })
    }
    
    /// Performs a request and optionally decodes the JSON response body.
    /// Returns `nil` if the server responded with status 404 - Not found
    public func request<Return>(method: HTTPMethod = .GET,
                                url: String,
                                query: Query? = nil,
                                headers: HTTPHeaders = HTTPHeaders(),
                                decoder: JSONDecoder? = nil,
                                as: Return?.Type)
        -> EventLoopFuture<Return?>
        where Return: Decodable
    {
        do {
            let url = try resolve(url: url, query: query)
            let request = ClientRequest(url: url, headers: headers)
            let promise = eventLoop.makePromise(of: Return?.self)
            
            send(request)
                .flatMapThrowing({ response -> Return? in
                    if response.status == .notFound {
                        return .none
                    }
                    
                    return try self.decodeResponseBody(request: request, response: response)
                })
                .whenComplete({ result in
                    switch result {
                    case .success(let value):
                        promise.succeed(value)
                        
                    case .failure(let error):
                        if let error = error as? ClientRequestError {
                            if error.response?.status == .notFound {
                                return promise.succeed(nil)
                            }
                        }
                        promise.fail(error)
                    }
                })
            
            return promise.futureResult
        }
        catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    /// Performs a request with JSON payload
    public func request<Send>(method: HTTPMethod = .GET,
                              url: String,
                              query: Query? = nil,
                              json: Send,
                              encoder: JSONEncoder? = nil,
                              headers: HTTPHeaders = HTTPHeaders())
        -> EventLoopFuture<ClientResponse> where Send: Encodable
    {
        do {
            let url = try resolve(url: url, query: query)
            var request = ClientRequest(method: method, url: url, headers: headers)
            
            do {
                try request.content.encode(json, using: encoder ?? defaultEncoder)
            }
            catch {
                throw ClientRequestError.wrap(error, request)
            }
            
            return send(request)
        }
        catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    /// Performs a request with JSON paylod and JSON response
    public func request<Send, Return>(method: HTTPMethod = .GET,
                                      url: String,
                                      query: Query? = nil,
                                      json: Send,
                                      encoder: JSONEncoder? = nil,
                                      decoder: JSONDecoder? = nil,
                                      headers: HTTPHeaders = HTTPHeaders(),
                                      as: Return.Type)
        -> EventLoopFuture<Return>
        where Send: Encodable, Return: Decodable
    {
        do {
            let url = try resolve(url: url, query: query)
            var request = ClientRequest(method: method, url: url, headers: headers)
            
            do {
                try request.content.encode(json, using: encoder ?? defaultEncoder)
            }
            catch {
                throw ClientRequestError.wrap(error, request)
            }
            
            return send(request)
                .flatMapThrowing({ response in
                    try response.content
                        .decode(Return.self, using: decoder ?? self.defaultDecoder)
                })
                .mapErrorToClientRequestError(request: request)
        }
        catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    public func decodeResponseBody<T: Decodable>(request: ClientRequest, response: ClientResponse, decoder: JSONDecoder? = nil) throws -> T {
        do {
            if T.self == String.self {
                return try decodeStringResponse(request: request, response: response) as! T
            }
            
            return try response.content.decode(T.self, using: decoder ?? defaultDecoder)
        }
        catch {
            throw ClientRequestError.wrap(error, request, response)
        }
    }
    
    public func decodeStringResponse(request: ClientRequest, response: ClientResponse, decoder: JSONDecoder? = nil) throws -> String {
        guard var body = response.body else {
            throw ClientRequestError(request: request, response: response, message: "Empty body")
        }
        
        guard let data = body.readData(length: body.readableBytes) else {
            throw ClientRequestError(request: request, response: response, message: "Failed to read body data")
        }
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw ClientRequestError(request: request, response: response, message: "Failed to decode body")
        }
        
        return string
    }
    
}

// MARK: - private

private extension RestClient {

//    static func errorId(_ id: String) -> String {
//        return "RestClient.\(id)"
//    }
    
    /// Sends a request and returns a Future tuple of Request and Response
    private func sendRequest(method: HTTPMethod = .GET,
                             url: String,
                             query: Query? = nil,
                             headers: HTTPHeaders = HTTPHeaders(),
                             body: ByteBuffer? = nil)
        -> EventLoopFuture<(ClientRequest, ClientResponse)>
    {
        do {
            let uri = try resolve(url: url, query: query)
            let request = ClientRequest(method: method, url: uri, headers: headers, body: body)
            
            return send(request)
                .map({ response in (request, response) })
                .mapErrorToClientRequestError(request: request)
        }
        catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

}

// MARK: - Responder

extension RestClient: RestClientResponder {

    public func respond(to request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        return client.send(request)
    }
    
}
