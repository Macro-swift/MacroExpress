//
//  ProcessingContext.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021-2025 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer
import http
import connect

internal extension multer {
  
  /**
   * This is the main driver for processing the multipart/form-data content.
   *
   * It collects the plain field values,
   * pushes file data into the storage
   * and validates limits.
   */
  final class Context: MulterStorageContext {
    
    let multer        : multer
    let restrictions  : [ String : Int? ]? // fieldname to maxCount
    let request       : IncomingMessage
    let response      : ServerResponse
    var next          : Next?
    var parser        : MultiPartParser

    var config        : multer { return multer }

    init(request      : IncomingMessage,
         response     : ServerResponse,
         boundary     : String,
         multer       : multer,
         restrictions : [ String : Int? ]?,
         next         : @escaping Next)
    {
      self.request      = request
      self.response     = response
      self.next         = next
      self.multer       = multer
      self.restrictions = restrictions
      self.parser       = MultiPartParser(boundary: boundary)
    }
    
    private let defaultFieldValueEncoding : String.Encoding = .utf8
    
    private var fieldValueEncoding : String.Encoding? {
      guard let charsetBuffer = self.values["_charset_"]?.first else {
        return nil
      }
      guard let charset = try? charsetBuffer.toString(.utf8) else {
        request.log
          .error("Could not decode formdata encoding buffer:", charsetBuffer)
        return nil
      }
      return String.Encoding
        .encodingWithName(charset, fallbackEncoding: defaultFieldValueEncoding)
    }
    
    private func buildFormValues() -> [ String : Any ] {
      guard !values.isEmpty else { return [:] }
      
      let encoding   = fieldValueEncoding ?? defaultFieldValueEncoding
      var formValues = [ String : Any ]()
      formValues.reserveCapacity(values.count)
      for ( name, value ) in values {
        switch value {
          case .single(let buffer):
            if let s = try? buffer.toString(encoding) { formValues[name] = s }
            else                                      {
              formValues[name] = buffer
            }
          case .multiple(let buffers):
            assert(buffers.count > 1)
            let strings = buffers.compactMap  { try? $0.toString(encoding) }
            if strings.count == buffers.count { formValues[name] = strings }
            else                              { formValues[name] = buffers }
        }
      }
      return formValues
    }
    
    func finish() {
      parser.end(handler: handleEvent)
      guard let next = next else { return } // nothing will handle the result?
      
      switch request.body {
      
        case .notParsed:
          if values.isEmpty {
            request.body = .urlEncoded([:])
          }
          else {
            request.body = .urlEncoded(buildFormValues())
          }
          
        case .urlEncoded(var values):
          if !values.isEmpty {
            values.merge(buildFormValues(), uniquingKeysWith: { $1 })
            request.body = .urlEncoded(values)
          }
          
        default:
          if !values.isEmpty {
            request.log.warn(
              "Not storing multipart/form-data values, body already set!")
          }
      }
      
      // Filter out empty files.
      for ( field, fieldFiles ) in files where fieldFiles.count == 1 {
        guard let fieldFile = fieldFiles.first, fieldFile.isEmpty else {
          continue
        }
        files[field] = [] // this is an empty file
      }
      
      request.files = files
      
      next()
      self.next = nil
    }
    func write(_ bytes: Buffer) { parser.write(bytes, handler: handleEvent) }
    
    func handleError(_ error: Swift.Error) {
      if case .notParsed = request.body { request.body = .error(error) }
      guard let next = next else { return }
      next(error)
      self.next = nil
      
      // TBD: Is this sensible? I think so.
      request.destroy(error)
    }
    
    
    // MARK: - Parser
    
    private enum FieldValue {
      case single  (Buffer)
      case multiple([ Buffer ])
      
      var first: Buffer? {
        switch self {
          case .single  (let buffer)  : return buffer
          case .multiple(let buffers) : return buffers.first
        }
      }
    }
    
    private var values     = [ String : FieldValue ]()
    private var files      = [ String : [ File ]]()
    private var header     : [ ( name: String, value: String ) ]?
    private var bodyData   : Buffer?
    private var activePart = PartType.invalid

    private var fileCount  : Int { return files.nestedCount }
    
    private func finishPart() {
      defer { header = nil; bodyData = nil; activePart = .invalid }
      guard let header = header else { return }
      request.log.trace("end part:", header, bodyData, values)
    }
    
    /**
     * Check whether the given part would exceed a restriction in either the
     * multer config, or the name/max-count array.
     */
    private func exceedsPartRestriction(_ partType: PartType) -> MulterError? {
      if let v = multer.limits.fieldNameSize {
        guard partType.name.count <= v else { return .fieldNameTooLong }
      }
      
      switch partType {
        case .invalid: break
          
        case .field:
          if let v = multer.limits.fields {
            guard v < self.values.count else { return .tooManyFields }
          }
          
        case .file(let file):
          let name = file.fieldName
          if let restrictions = restrictions {
            guard let restriction = restrictions[name] else {
              return .limitUnexpectedFile(fieldName: name)
            }
            if let v = restriction {
              let existingCount = files[name]?.count ?? 0
              guard existingCount < v else { return .tooManyFiles }
            }
            // else: unrestricted count
          }
          if let v = multer.limits.files {
            guard fileCount < v else { return .tooManyFiles }
          }
      }
      
      return nil
    }
    
    /**
     * This is our MultiPartParser handler function.
     * We feed data into the parser, and the parser calls us back with parsed
     * events.
     */
    private func handleEvent(_ event: MultiPartParser.Event) {
      guard next != nil else {
        return request.log
          .warn("multipart parse event, but next has been called:", event)
      }
      
      // TODO: this needs to write into the storage
      switch event {
      
        case .parseError(let error):
          request.log.error("multipart/form-data parse error:", error)
          handleError(error)
          
        case .preambleData(let buffer):
          if !buffer.isEmpty {
            request.log.log("ignoring multipart preamble:", buffer)
          }
        case .postambleData(let buffer):
          if !buffer.isEmpty {
            request.log.log("ignoring multipart postamble:", buffer)
          }
        
        case .startPart(let header):
          finishPart() // close existing
          
          let partType = PartType(with: header)
          
          if case .invalid = partType {
            request.log.error("Invalid multipart/form-data part:", header)
            return handleError(MulterError.invalidPartHeader(header))
          }
          if let error = exceedsPartRestriction(partType) {
            request.log.error("Limit hit for multipart part:", partType.name,
                              error)
            return handleError(error)
          }

          self.header     = header
          self.activePart = partType
          request.log.trace("start part:", partType, header)
          
          if case .file(let file) = partType {
            files[file.fieldName, default: []].append(file)
            multer.storage.startFile(file, in: self)
          }
          
        case .endPart:
          switch activePart {
            case .invalid         : break
            case .file (let file) : multer.storage.endFile(file, in: self)
            case .field(let name) : endField(name)
          }
          finishPart()
          
        case .bodyData(let data):
          switch activePart {
            case .invalid       : break
            case .file(let file):
              do    { try multer.storage.write(data, to: file, in: self) }
              catch { handleError(error) }
            case .field         : addFieldData(data)
          }
      }
    }
    
    
    // MARK: - Deal with field data
    
    private func addFieldData(_ data: Buffer) {
      if let v = multer.limits.fileSize {
        let newSize = (bodyData?.count ?? 0) + data.count
        guard newSize <= v else {
          return handleError(MulterError.fieldValueTooLong)
        }
      }
      if nil == bodyData?.append(data) { bodyData = data }
    }
    
    private func endField(_ name: String) {
      let fieldBuffer = bodyData ?? Buffer(capacity: 0)
      bodyData = nil
      
      if var value = values.removeValue(forKey: name) {
        switch value {
          case .single(let buffer):
            value = .multiple([ buffer, fieldBuffer ])
          case .multiple(var buffers):
            buffers.append(fieldBuffer)
            value = .multiple(buffers)
        }
      }
      else {
        values[name] = .single(fieldBuffer)
      }
    }
  }
}
