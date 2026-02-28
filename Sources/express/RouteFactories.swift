//
//  RouteFactories.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 2023-04-16.
//  Copyright © 2016-2025 ZeeZide GmbH. All rights reserved.
//

import typealias connect.Middleware
import typealias connect.FinalMiddleware
import typealias connect.AsyncMiddleware
import typealias connect.AsyncFinalMiddleware
import func      connect.async
import NIOHTTP1

// TBD: All the duplication below looks a little stupid, is there a better way
//      w/o resorting to Any? Also we can only take uniform lists of middleware
//      (e.g. not mix & match regular and error mw)

public extension RouteKeeper {
  
  // MARK: - Use // All
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: nil, middleware: middleware))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware))
    return self
  }
  
  // MARK: - GET / POST / HEAD / PUT / DELETE / PATCH
  
  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String,
             _ middleware: Middleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     middleware: middleware))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .GET,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .POST,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .HEAD,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PUT,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .DELETE,
                     middleware: middleware))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ middleware: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PATCH,
                     middleware: middleware))
    return self
  }
}


// MARK: - Final Versions

@usableFromInline
func final2middleware(_ finalMiddleware: @escaping FinalMiddleware)
     -> Middleware
{
  { req, res, _ in try finalMiddleware(req, res) }
}

public extension RouteKeeper {
  
  // MARK: - Use // All
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ middleware: Middleware..., 
           final: @escaping FinalMiddleware) -> Self 
  {
    add(route: Route(id: id, pattern: nil, method: nil,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  
  // MARK: - GET / POST / HEAD / PUT / DELETE / PATCH
  
  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware..., final: @escaping FinalMiddleware) 
        -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware..., final: @escaping FinalMiddleware) 
        -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String,
             _ middleware: Middleware..., final: @escaping FinalMiddleware) 
         -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil,
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .GET,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil,
            _ middleware: Middleware..., final: @escaping FinalMiddleware) 
        -> Self
   {
    add(route: Route(id: id, pattern: nil, method: .POST,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, 
            _ middleware: Middleware..., final: @escaping FinalMiddleware) 
        -> Self
   {
    add(route: Route(id: id, pattern: nil, method: .HEAD,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, 
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .PUT,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, 
           _ middleware: Middleware..., final: @escaping FinalMiddleware) 
       -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .DELETE,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil,
             _ middleware: Middleware..., final: @escaping FinalMiddleware) 
         -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .PATCH,
                     middleware: middleware + [ final2middleware(final) ]))
    return self
  }
}


// MARK: - Error Middleware Versions

public extension RouteKeeper {

  // MARK: - Use // All

  @discardableResult
  @inlinable
  func use(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: nil,
                     errorMiddleware: errorMiddleware))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String,
           _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     
                     errorMiddleware: errorMiddleware))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String,
           _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     errorMiddleware: errorMiddleware))
    return self
  }


  // MARK: - GET / POST / HEAD / PUT / DELETE / PATCH

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String,
           _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String,
            _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String,
            _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String,
           _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String,
           _ errorMiddleware: ErrorMiddleware...) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String,
             _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     errorMiddleware: errorMiddleware))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .GET,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .POST,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .HEAD,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PUT,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .DELETE,
                     errorMiddleware: errorMiddleware))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ errorMiddleware: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PATCH,
                     errorMiddleware: errorMiddleware))
    return self
  }
}


// MARK: - Async Versions

public extension RouteKeeper {

  // MARK: - Use // All

  @discardableResult
  @inlinable
  func use(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: nil,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }

  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }

  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }

  // MARK: - GET / POST / HEAD / PUT / DELETE / PATCH

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String,
             _ middleware: Middleware...,
             asyncMiddleware: [ AsyncMiddleware ] = [],
             async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .GET,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .POST,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .HEAD,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .PUT,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .DELETE,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ middleware: Middleware...,
             asyncMiddleware: [ AsyncMiddleware ] = [],
             async lastMiddleware: @escaping AsyncMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .PATCH,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(lastMiddleware) ]))
    return self
  }
}


// MARK: - Async Final Versions

public extension RouteKeeper {

  // MARK: - Use // All

  @discardableResult
  @inlinable
  func use(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: nil,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }

  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }

  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }

  // MARK: - GET / POST / HEAD / PUT / DELETE / PATCH

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String,
            _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String,
           _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String,
             _ middleware: Middleware...,
             asyncMiddleware: [ AsyncMiddleware ] = [],
             asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .GET,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .POST,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ middleware: Middleware...,
            asyncMiddleware: [ AsyncMiddleware ] = [],
            asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .HEAD,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .PUT,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ middleware: Middleware...,
           asyncMiddleware: [ AsyncMiddleware ] = [],
           asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .DELETE,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ middleware: Middleware...,
             asyncMiddleware: [ AsyncMiddleware ] = [],
             asyncFinal: @escaping AsyncFinalMiddleware) -> Self
  {
    add(route: Route(id: id, pattern: nil, method: .PATCH,
                     middleware: middleware
                       + asyncMiddleware.map(async)
                       + [ async(asyncFinal) ]))
    return self
  }
}
