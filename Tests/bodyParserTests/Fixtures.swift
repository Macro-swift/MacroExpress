import Macro
import connect

enum Fixtures {

  enum SimpleFormData {
    static let boundary = "----WebKitFormBoundaryHU6Dqpfe9L4ATppg"
    static let data = Buffer(
      """
      --\(boundary)\r
      Content-Disposition: form-data; name="title"\r
      \r
      file.csv\r
      --\(boundary)\r
      Content-Disposition: form-data; name="file"; filename=""\r
      Content-Type: application/octet-stream\r
      \r
      \r
      --\(boundary)--\r\n
      """
    )
    
    static let expectedEvents : [ MultiPartParser.Event ] = [
      .startPart([
        ( "Content-Disposition" , "form-data; name=\"title\"" )
      ]),
      .bodyData(Buffer("file.csv")),
      .endPart,
      .startPart([
        ( "Content-Disposition" , "form-data; name=\"file\"; filename=\"\"" ),
        ( "Content-Type"        , "application/octet-stream" )
      ]),
      .endPart
    ]
  }
}
