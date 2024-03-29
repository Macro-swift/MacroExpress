# Macro Express

Express is a Macro module modelled after the
[ExpressJS](http://expressjs.com)
framework.
As usual in Macro the module is supposed to be as similar as possible.

Express is a module based on top of 
[Connect](../connect).
It is also based on middleware, but adds 
additional routing features,
support for templates (defaults to Mustache),
and more fancy conveniences for JSON, etc ;-)

Show us some code! Example:

```swift
import express

let __dirname = process.cwd() // our modules have no __dirname

let app = express()

// Hook up middleware:
// - logging
// - POST form value decoder
// - cookie parsing (looks for cookies, adds them to the request)
// - session handling
// - serve files in 'public' directory
app.use(logger("dev"))
app.use(bodyParser.urlencoded())
app.use(cookieParser())
app.use(session())
app.use(serveStatic(__dirname + "/public"))

// Setup dynamic templates: Mustache templates ending in .html in the
// 'views' directory.
app.set("view engine", "html") // really mustache, but we want to use .html
app.set("views", __dirname + "/views")

// Simple session based counter middleware:
app.use { req, _, next in
  req.session["viewCount"] = req.session[int: "viewCount"] + 1
  next() // just counting, no HTTP processing
}

// Basic form handling:
// - If the browser sends 'GET /form', render the
//   Mustache template in views/form.html.
// - If the browser sends 'POST /form', grab the values and render the
//   form with them
app.get("/form") { _, res in
  res.render("form")
}
app.post("/form") { req, res in
  let user = req.body[string: "user"] // form value 'user'
  
  let options : [ String : Any ] = [
    "user"      : user,
    "nouser"    : user.isEmpty
  ]
  res.render("form", options)
}

app.listen(1337) { print("Server listening: \($0)") }
```

A sample Mustache template:

```mustache
{{> header}}    
  <form action="/form" method="POST">
    <label>
      User <input name="user" type="text" placeholder="username"
                  value="{{user}}" />
    </label>
    <label>
      Password <input name="p" type="password" placeholder="password" />
    </label>
    
    <input type="submit" class="button" value="Submit" />
  </form>
{{> footer}}
```

This includes header/footer templates via `{{> header}}` and it renders values
using `{{user}}`. You get the idea.
