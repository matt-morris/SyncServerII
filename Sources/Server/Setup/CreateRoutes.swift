//
//  CreateRoutes.swift
//  Server
//
//  Created by Christopher Prince on 6/2/17.
//
//

import Foundation
import Kitura
import SyncServerShared
import LoggerAPI

class CreateRoutes {
    private var router = Router()

    init() {
    }
    
    func addRoute(ep:ServerEndpoint, processRequest: @escaping ProcessRequest) {

        func handleRequest(routerRequest:RouterRequest, routerResponse:RouterResponse) {
            Log.info("parsedURL: \(routerRequest.parsedURL)")
            let handler = RequestHandler(request: routerRequest, response: routerResponse, endpoint:ep)
            
            let create:(RouterRequest) -> (RequestMessage?) = ep.requestMessageType.init
            handler.doRequest(createRequest: create, processRequest: processRequest)
        }
        
        switch (ep.method) {
        case .get:
            self.router.get(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
            
        case .post:
            self.router.post(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
        
        case .patch:
            self.router.patch(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
        
        case .delete:
            self.router.delete(ep.pathWithSuffixSlash) { routerRequest, routerResponse, _ in
                handleRequest(routerRequest: routerRequest, routerResponse: routerResponse)
            }
        }
    }
    
    func getRoutes() -> Router {
        ServerSetup.credentials(self.router)
        ServerRoutes.add(proxyRouter: self)

        self.router.error { request, response, _ in
            let handler = RequestHandler(request: request, response: response)
            
            let errorDescription: String
            if let error = response.error {
                errorDescription = "\(error)"
            } else {
                errorDescription = "Unknown error"
            }
            
            let message = "Server error: \(errorDescription)"
            handler.failWithError(message: message)
        }

        self.router.all { request, response, _ in
            let handler = RequestHandler(request: request, response: response)
            let message = "Route not found in server: \(request.originalURL)"
            response.statusCode = .notFound
            handler.failWithError(message: message)
        }
        
        return self.router
    }
}

