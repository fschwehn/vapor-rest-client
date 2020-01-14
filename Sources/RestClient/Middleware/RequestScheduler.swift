//
//  RequestScheduler.swift
//  RestClient
//
//  Created by Florian Schwehn on 31.01.19.
//

import Vapor

//public class RequestScheduler: Middleware {
//    
//    let container: Container
//    let maxRequestsPerSecond: Int
//    let maxParralelRequests: Int
//    
//    private typealias QueueItem = (request: Request, next: Responder, promise: EventLoopPromise<Response>)
//    
//    private var requestQueue = [QueueItem]()
//    private var numRequestsSentWithinLastSecond = 0
//    private var currentNumberOfRequests = 0
//    
//    public init(container: Container, maxRequestsPerSecond: Int, maxParralelRequests: Int) {
//        self.container = container
//        self.maxRequestsPerSecond = maxRequestsPerSecond
//        self.maxParralelRequests = maxParralelRequests
//    }
//    
//    public func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
//        let promise = request.sharedContainer.eventLoop.newPromise(Response.self)
//        requestQueue.append((request, next, promise))
//        process()
//        return promise.futureResult
//    }
//    
//    private func process() {
//        while !requestQueue.isEmpty
//            && numRequestsSentWithinLastSecond < maxRequestsPerSecond
//            && currentNumberOfRequests < maxParralelRequests
//        {
//            numRequestsSentWithinLastSecond += 1
//            let item = requestQueue.removeFirst()
//            
//            do {
//                currentNumberOfRequests += 1
//                try item.next
//                    .respond(to: item.request)
//                    .do({ _ in
//                        self.currentNumberOfRequests -= 1
//                        self.container.eventLoop.execute(self.process)
//                    })
//                    .cascade(promise: item.promise)
//            }
//            catch {
//                item.promise.fail(error: error)
//            }
//            
//            container.eventLoop.scheduleTask(in: .seconds(1)) { () -> Void in
//                self.numRequestsSentWithinLastSecond -= 1
//                self.process()
//            }
//        }
//    }
//    
//}
