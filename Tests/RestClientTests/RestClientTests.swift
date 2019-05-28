import XCTest
import Vapor

@testable import RestClient

struct TestClient: Client {
    
    let container: Container
    
    func send(_ req: Request) -> EventLoopFuture<Response> {
        do {
            var http = HTTPResponse(status: .ok)
            switch req.http.url.path {
            case "/ok":
                break
            case "/query":
                let res = Response(http: http, using: req)
                let query = try req.query.decode([String:String].self)
                try! res.content.encode(query)
                return req.future(res)
            default:
                http.status = .notFound
            }
            
            return req.future(Response(http: http, using: req))
        }
        catch {
            let http = HTTPResponse(status: .internalServerError)
            return req.future(Response(http: http, using: req))
        }
    }
    
}

final class RestClientTests: XCTestCase {

    var app: Application!
    var client: RestClient!
    
    override func setUp() {
        super.setUp()
        
        app = try! Application()
        let testClient = TestClient(container: app)
        client = try! RestClient(container: app, hostUrl: "https://example.com", client: testClient)
        client.middlewares = [
            StatusCodeToErrorTransformer()
        ]
    }
    
    func test_200() throws {
        let (_, res) = try client.request(url: "/ok").wait()
        XCTAssertTrue(res.http.status == .ok)
    }
    
    func test_404() throws {
        do {
            _ = try client.request(url: "/undefined").wait()
            XCTFail("call should throw")
        }
        catch {
            switch error {
            case let error as RequestError:
                XCTAssertTrue(error.status == .notFound)
            default:
                XCTFail("error should be instance of \(RequestError.self)")
            }
        }
    }
    
    func test_query() throws {
        let url = "/query"
        let query = [
            "filter": "name = 'John&Me' and age = 42",
            "count": "2",
        ]
        let result = try client.request(url: url, query: query, as: [String:String].self).wait()
        XCTAssertEqual(query, result)
    }

    static let allTests = [
        ("test_200", test_200),
        ("test_404", test_404),
        ("test_query", test_query),
    ]
    
}
