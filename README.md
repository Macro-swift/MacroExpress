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
[swift-sh](https://github.com/mxcl/swift-sh) scripts.

```swift
#!/usr/bin/swift sh
import MacroExpress // @Macro-swift

let app = express()
app.use(logger("dev"))
app.use(bodyParser.urlencoded())
app.use(serveStatic(__dirname() + "/public"))

app.get("/hello") { req, res, next in
  res.send("Hello World!")
}
app.get { req, res, next in
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
[Helge Heß](https://github.com/helje5/) / [ZeeZide](https://zeezide.de).
We like feedback, GitHub stars, cool contract work, 
presumably any form of praise you can think of.

**Want to support my work**?
Buy an app:
[Code for SQLite3](https://apps.apple.com/us/app/code-for-sqlite3/id1638111010),
[Past for iChat](https://apps.apple.com/us/app/past-for-ichat/id1554897185),
[SVG Shaper](https://apps.apple.com/us/app/svg-shaper-for-swiftui/id1566140414),
[HMScriptEditor](https://apps.apple.com/us/app/hmscripteditor/id1483239744).
You don't have to use it! 😀
