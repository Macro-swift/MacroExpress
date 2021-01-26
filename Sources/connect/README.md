<h2>Macro Connect
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

Connect is a Macro module modelled after the
[Connect](https://github.com/senchalabs/connect#readme)
JavaScript framework from SenchaLabs.
As usual in Noze.io the module is supposed to be as similar as possible.

Connect builds on top of the Macro http module.
It adds the concept of *middleware*. Middleware are just functions that can
deal with HTTP requests. 
They take a request (`IncomingMessage`) and response (`ServerResponse`) object 
as well as a  callback to signal whether they fully handled the request 
or whether Connect should run the next middleware.
That way you can stack middleware functions in a processing queue.
Some middleware will just enhance the
request object, like the cookie-parser, while some other middleware can deliver
data, like the `serveStatic` middleware.

**Express**: Connect adds the concept of middleware to the `http` module. Note
that there is another module called
[Express](../express)
which builds on top of Connect. Express provides even more advanced routing
capabilities and other extras.

Show us some code! Example:

```swift
import connect
import process

let __dirname = process.cwd()

let app = connect()
app.use(logger("dev")) // this middleware logs requests
app.use(serveStatic(_dirname + "/public"))
app.listen(1337) { print("server lisetning: \($0)") }
```

It is a very basic HTTP server that serves all files living in the 'public'
directory and logs the requests on stdout.

## Included Middleware

- [pause](Pause.swift)
- [serveStatic](ServeStatic.swift)
- [session](Session.swift)
- [methodOverride](MethodOverride.swift)
- [bodyParser](BodyParser.swift)
  - [bodyParser.urlencoded](BodyParser.swift)
  - [bodyParser.json](BodyParser.swift)
  - [bodyParser.raw](BodyParser.swift)
  - [bodyParser.tex](BodyParser.swift)
- [cookieParser](CookieParser.swift)
- [cors](CORS.swift)
- [logger](Logger.swift)
