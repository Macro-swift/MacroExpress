<h2>Macro Multer
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

A package for parsing `multipart/form-data` payloads.

E.g. files submitted using an HTML form like:
```html
<form action="/upload" method="POST" enctype="multipart/form-data">
  <input type="file" name="file" multiple="multiple" />
  <input type="submit" value="Upload" />
</form>
```

Roughly designed after the Node [multer](https://github.com/expressjs/multer#readme)
package.


**Note**: DiskStorage is prepared, but not working yet.

### Example

[Examples](https://github.com/Macro-swift/Examples/blob/main/Sources/express-simple/main.swift#L48)
```swift
app.post("/multer", multer().array("file", 10)) { req, res, _ in
    req.log.info("Got files:", req.files["file"])
    res.render("multer", [
      "files": req.files["file"]?.map {
         [ "name":     $0.originalName,
           "size":     $0.buffer?.length ?? 0,
           "mimeType": $0.mimeType ]
      } ?? [],
      "hasFiles": !(req.files["file"]?.isEmpty ?? true)
    ])
}
```


### Links

- [Multer](https://github.com/expressjs/multer#readme)
- [Macro](https://github.com/Macro-swift/Macro/)
- [SwiftNIO](https://github.com/apple/swift-nio)

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
