//
//  RestClient.swift
//  RestClient
//
//  Created by Florian Schwehn on 30.01.19.
//

import Vapor

open class RestClient {
    
    public typealias Query = [String:String]
    
    /// The container this client acts on
    public let container: Container
    
    /// Common prefix for all requests (e.g. "https://api.example.com/v1")
    public let hostUrl: URL
    
    /// Middleware stack for request processing
    public var middleware = [Middleware]()
    
    public var defaultDecoder: JSONDecoder = JSONDecoder()
    
    public var defaultEncoder: JSONEncoder = JSONEncoder()
    
    private let client: Client
    
    /// Creates a `RestClient`
    ///
    /// - Parameters:
    ///   - container: see `container`
    ///   - hostUrl: see `hostUrl`
    /// - Throws: `RestClient.Error`
    public init(container: Container, hostUrl: URLRepresentable, client: Client? = nil) throws {
        self.container = container
        self.client = try client ?? container.client()
        
        guard let url = hostUrl.convertToURL() else {
            throw VaporError(identifier: RestClient.errorId("malformedHostUrl"), reason: "Malformed host URL: \(hostUrl)")
        }
        self.hostUrl = url
    }
    
    /// Resolves a given (incomplete) URL to `hostUrl`
    ///
    /// - Parameters:
    ///   - url: The URL to resolve
    ///   - query: optional query to append
    /// - Returns: resolved URL
    public func resolve(url: String, query: Query?) throws -> String {
        let hostUrlString = hostUrl.absoluteString
        var urlString = url.starts(with: hostUrlString)
            ? url
            : hostUrlString + url
        
        if let query = query {
            guard var comps = URLComponents(string: urlString) else {
                throw VaporError(identifier: RestClient.errorId("resolveUrl"), reason: "Failed to form URLComponents from String '\(urlString)'")
            }
            
            if !query.isEmpty {
                var queryItems = comps.queryItems ?? [URLQueryItem]()
                
                for (name, value) in query {
                    queryItems.append(URLQueryItem(name: name, value: value))
                }
                
                comps.queryItems = queryItems
                
                guard let parsedUrl = comps.url else {
                    throw VaporError(identifier: RestClient.errorId("resolveQuery"), reason: "Failed to form URL from URLComponents \(comps)")
                }
                
                urlString = parsedUrl.absoluteString
            }
        }
        
        return urlString
    }
    
    /// Kernel function - sends a `Request` down the responder chain of our `middleware`
    func send(_ req: Request) -> Future<Response> {
        let responder = middleware.makeResponder(chainingTo: self)
        let promise = container.eventLoop.newPromise(Response.self)
        
        container.eventLoop.execute {
            do {
                try responder.respond(to: req).cascade(promise: promise)
            }
            catch {
                promise.fail(error: error)
            }
        }
        
        return promise.futureResult
    }
    
    /// Performs a request
    public func request(method: HTTPMethod = .GET,
                        url: String,
                        query: Query? = nil,
                        headers: HTTPHeaders = HTTPHeaders(),
                        body: LosslessHTTPBodyRepresentable = HTTPBody())
        throws -> Future<(Request, Response)>
    {
        let url = try resolve(url: url, query: query)
        let httpRequest = HTTPRequest(method: method, url: url, headers: headers, body: body)
        let request = Request(http: httpRequest, using: self.container)
        
        return send(request)
            .map({ response in (request, response) })
            .catchMap({ error in throw RequestError.wrap(error, request) })
    }
    
    /// Performs a request and decodes the JSON response body
    public func request<Return>(method: HTTPMethod = .GET,
                                url: String,
                                query: Query? = nil,
                                headers: HTTPHeaders = HTTPHeaders(),
                                decoder: JSONDecoder? = nil,
                                as: Return.Type)
        throws -> Future<Return>
        where Return: Decodable
    {
        return try request(method: method, url: url, query: query, headers: headers)
            .flatMap({ (request, response) in
                try response.content
                    .decode(json: Return.self, using: decoder ?? self.defaultDecoder)
                    .catchFlatMap({ error in
                        throw RequestError.wrap(error, request, response)
                    })
            })
    }
    
    /// Performs a request and decodes the UTF8 response body
    public func request(method: HTTPMethod = .GET,
                        url: String,
                        query: Query? = nil,
                        headers: HTTPHeaders = HTTPHeaders(),
                        decoder: JSONDecoder? = nil,
                        as: String.Type)
        throws -> Future<String>
    {
        return try request(method: method, url: url, query: query, headers: headers)
            .map({
                let req = $0.0
                let res = $0.1
                
                guard let data = res.http.body.data else {
                    throw RequestError(request: req, response: res, message: "Empty body")
                }
                
                guard let string = String(data: data, encoding: .utf8) else {
                    throw RequestError(request: req, response: res, message: "Failed to decode body")
                }
                
                return string
            })
        
    }
    
    /// Performs a request with JSON payload
    public func request<Send>(method: HTTPMethod = .GET,
                              url: String,
                              query: Query? = nil,
                              json: Send,
                              encoder: JSONEncoder? = nil,
                              headers: HTTPHeaders = HTTPHeaders())
        throws -> Future<Response> where Send: Encodable
    {
        let url = try resolve(url: url, query: query)
        let httpRequest = HTTPRequest(method: method, url: url, headers: headers)
        let request = Request(http: httpRequest, using: self.container)
        
        do {
            try request.content.encode(json: json, using: encoder ?? defaultEncoder)
        }
        catch {
            throw RequestError.wrap(error, request)
        }
        
        return send(request)
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
        throws -> Future<Return>
        where Send: Encodable, Return: Decodable
    {
        let url = try resolve(url: url, query: query)
        let httpRequest = HTTPRequest(method: method, url: url, headers: headers)
        let request = Request(http: httpRequest, using: self.container)
        
        do {
            try request.content.encode(json: json, using: encoder ?? defaultEncoder)
        }
        catch {
            throw RequestError.wrap(error, request)
        }
        
        return send(request)
            .flatMap({ response in
                try response.content
                    .decode(json: Return.self, using: decoder ?? self.defaultDecoder)
                    .catchFlatMap({ throw RequestError.wrap($0, request, response) })
            })
    }
    
    /// Performs a GET request and decodes the JSON response body
    public func get<Return>(url: String,
                            query: Query? = nil,
                            headers: HTTPHeaders = HTTPHeaders(),
                            decoder: JSONDecoder? = nil,
                            as: Return.Type)
        throws -> Future<Return>
        where Return: Decodable
    {
        return try request(method: .GET, url: url, query: query, headers: headers)
            .flatMap({ (request, response) in
                try response.content
                    .decode(json: Return.self, using: decoder ?? self.defaultDecoder)
                    .catchFlatMap({ error in
                        throw RequestError.wrap(error, request, response)
                    })
            })
    }
    
    /// Performs a GET request and decodes the JSON response body
    ///
    /// This function does not trhrow errors if the requested resource does not exist
    /// (means if status code of the response is 404 - not found).
    public func get<Return>(url: String,
                            query: Query? = nil,
                            headers: HTTPHeaders = HTTPHeaders(),
                            decoder: JSONDecoder? = nil,
                            as: Return?.Type)
        throws -> Future<Return?>
        where Return: Decodable
    {
        let url = try resolve(url: url, query: query)
        let httpRequest = HTTPRequest(url: url, headers: headers)
        let request = Request(http: httpRequest, using: self.container)
        
        return send(request)
            .flatMap({ response in
                if response.http.status == .notFound {
                    return request.future(.none)
                }
                
                return try response.content
                    .decode(json: Return.self, using: decoder ?? self.defaultDecoder)
                    .map({ .some($0) })
            })
            .catchFlatMap({ error in
                if let error = error as? RequestError {
                    if error.response?.http.status == .notFound {
                       return request.future(.none)
                    }
                }
                
                throw RequestError.wrap(error, request)
            })
    }
    
}

// MARK: - private

private extension RestClient {
    
    static func errorId(_ id: String) -> String {
        return "RestClient.\(id)"
    }
    
}

// MARK: - Responder

extension RestClient: Responder {
    
    /// See `Vapor.Responder`
    public func respond(to req: Request) throws -> Future<Response> {
        return client.send(req)
    }
    
}
