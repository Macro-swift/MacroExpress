<h2>MacroExpress
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

A small, unopinionated "don't get into my way" / "I don't wanna `wait`" 
asynchronous web framework for Swift.
With a strong focus on replicating the Node APIs in Swift.
But in a typesafe, and fast way.

MacroExpress is a more capable variant of 
[µExpress](https://github.com/NozeIO/MicroExpress).
The goal is still to keep a small core, but add some 
[Noze.io](http://noze.io)
modules and concepts.

MacroExpress adds the web framework components to
[Macro](https://github.com/Macro-swift/Macro/)
(kinda like `Express.js` adds to `Node.js`).

[MacroLambda](https://github.com/Macro-swift/MacroLambda) has the bits to
directly deploy MacroExpress applications on AWS Lambda.
[MacroApp](https://github.com/Macro-swift/MacroApp) adds a SwiftUI-style
declarative DSL to setup MacroExpress routes.


## What does it look like?

The Macro [Examples](https://github.com/Macro-swift/Examples) package 
contains a few examples which all can run straight from the source as
swift-sh scripts.

```swift
#!/usr/bin/swift sh
import MacroExpress // @Macro-swift ~> 0.5.5

let app = express()
app.use(logger("dev"))
app.use(bodyParser.urlencoded())
app.use(serveStatic(__dirname() + "/public"))

app.get("/hello") { req, res, next in
  res.send("Hello World!")
}
app.get {
  res.render("index")
}

app.listen(1337)
```

## Environment Variables

- `macro.core.numthreads`
- `macro.core.iothreads`
- `macro.core.retain.debug`
- `macro.concat.maxsize`
- `macro.streams.debug.rc`
- `macro.router.debug`
- `macro.router.matcher.debug`
- `macro.router.walker.debug`

### Links

- [Macro](https://github.com/Macro-swift/Macro/)
- [µExpress](http://www.alwaysrightinstitute.com/microexpress-nio2/)
- [Noze.io](http://noze.io)
- [SwiftNIO](https://github.com/apple/swift-nio)
- JavaScript Originals
  - [Connect](https://github.com/senchalabs/connect)
  - [Express.js](http://expressjs.com/en/starter/hello-world.html)
- Swift Apache
  - [mod_swift](http://mod-swift.org)
  - [ApacheExpress](http://apacheexpress.io)

### Who

**MacroExpress** is brought to you by
the
[Always Right Institute](http://www.alwaysrightinstitute.com)
and
[ZeeZide](http://zeezide.de).
We like 
[feedback](https://twitter.com/ar_institute), 
GitHub stars, 
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.

There is a `#microexpress` channel on the 
[Noze.io Slack](http://slack.noze.io/). Feel free to join!
