//
//  Utilities.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//


internal func extractHeaderArgument(_ arg: String, from value: String)
              -> String?
{
  // Naive version, wish we had structured headers ;-)
  //   multipart/form-data; boundary="abc"
  //   multipart/form-data; boundary=abc
  let parts = value
    .split(separator: ";", maxSplits: 20, omittingEmptySubsequences: true)
    .map { $0.trimmingCharacters(in: .whitespaces) }
  
  guard let value = parts.first(where: { $0.hasPrefix("\(arg)=")})?
                         .dropFirst(arg.count + 1)
                         .trimmingCharacters(in: .whitespaces)
  else {
    return nil
  }
  
  if value.first == "\"" {
    guard value.count > 1 && value.last == "\"" else {
      assertionFailure("Unexpected \(arg) value quoting in: \(value)")
      return nil
    }
    return String(value.dropFirst().dropLast())
  }
  
  return value
}

internal extension Collection where Element == MultiPartParser.HeaderField {
  
  func valueForHeader(_ name: String) -> String? {
    if let pair = first(where: { $0.name == name }) { return pair.value }
    let lcName = name.lowercased()
    if let pair = first(where: { $0.name.lowercased() == lcName }) {
      return pair.value
    }
    return nil
  }
}

internal extension Dictionary {
  
  /// Same like `init(uniquingKeysWith:)`, but doesn't crash if abused.
  init(tolerantPairs: [ ( Key, Value ) ]) {
    self.init()
    reserveCapacity(tolerantPairs.count)
    for ( key, value ) in tolerantPairs {
      assert(self[key] == nil, "Detected duplicate key: \(key)")
      self[key] = value
    }
  }

}

internal extension Dictionary where Value: Collection {
  
  var nestedCount : Int {
    var count = 0
    for values in self.values { count += values.count }
    return count
  }
}
