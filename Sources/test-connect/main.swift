#!/usr/bin/swift sh

import Foundation
import MacroExpress // @Macro-swift ~> 0.0.2

let dirname = __dirname()

let app = connect()

#if false
  app.use { req, res, next in
    console.log("request:", req.url)
    res.onceFinish {
      console.log("finished request!", req)
    }
    next()
  }
  app.use { _, res, _ in
    res.send("Hello World!")
    console.log("did send")
  }

#elseif true

  app.use(logger("dev")) // Middleware: logs the request
  app.use(pause(2))
  app.use { req, res, next in
    #if true
      res.writeHead(200)
      res.end()
    #else
      res.sendStatus(404)
    #endif
  }

#elseif true

  app.use(logger("dev")) // Middleware: logs the request

  app.use(pause(2))

  let servePath = __dirname() + "/public"
  console.log("serving:", servePath)
  app.use(serveStatic(__dirname() + "/public"))
#endif


app.listen(1337) {
    console.log("Server listening on http://localhost:1337/")
}
