//
//  ExpressWrappedDictionary.swift
//  MacroExpress
//
//  Created by Helge Heß on 14.07.24.
//  Copyright © 2024-2025 ZeeZide GmbH. All rights reserved.
//

/**
 * This is a wrapper for dictionaries, that behaves like a dictionary,
 * but also allows access to the keys using `dynamicMemberLookup`.
 *
 * For example:
 * ```swift
 * let service = request.query.service
 * ```
 */
@dynamicMemberLookup
public struct ExpressWrappedDictionary<V>: Collection {

  public typealias WrappedType = [ String : V ]
  
  public typealias Key         = WrappedType.Key
  public typealias Value       = WrappedType.Value
  public typealias Keys        = WrappedType.Keys
  public typealias Values      = WrappedType.Values

  public typealias Element     = WrappedType.Element
  public typealias Index       = WrappedType.Index
  public typealias Indices     = WrappedType.Indices
  public typealias SubSequence = WrappedType.SubSequence
  public typealias Iterator    = WrappedType.Iterator

  public var dictionary : WrappedType
  
  @inlinable
  public init(_ dictionary: WrappedType) { self.dictionary = dictionary }
}

extension ExpressWrappedDictionary: Equatable where V: Equatable {}
extension ExpressWrappedDictionary: Hashable  where V: Hashable  {}

public extension ExpressWrappedDictionary {
  
  // MARK: - Dictionary
  
  @inlinable var keys    : Keys    { return dictionary.keys    }
  @inlinable var values  : Values  { return dictionary.values  }

  @inlinable subscript(_ key: Key) -> Value? {
    set { dictionary[key] = newValue }
    get { return dictionary[key] }
  }
  @inlinable subscript(key: Key, default defaultValue: @autoclosure () -> Value)
             -> Value
  {
    set { dictionary[key] = newValue } // TBD
    get { return self[key] ?? defaultValue() }
  }
  
  // MARK: - Sequence

  @inlinable
  func makeIterator() -> Iterator { return dictionary.makeIterator() }
  
  // MARK: - Collection
  
  @inlinable var indices : Indices { return dictionary.indices }
  @inlinable var startIndex : Index { return dictionary.startIndex }
  @inlinable var endIndex   : Index { return dictionary.endIndex   }
  @inlinable func index(after i: Index) -> Index {
    return dictionary.index(after: i)
  }
  @inlinable
  func formIndex(after i: inout Index) { dictionary.formIndex(after: &i) }

  @inlinable
  subscript(position: Index) -> Element { return dictionary[position] }

  @inlinable
  subscript(bounds: Range<Index>) -> Slice<WrappedType> {
    return dictionary[bounds]
  }
  @inlinable func index(forKey key: Key) -> Index? {
    return dictionary.index(forKey: key)
  }

  @inlinable var isEmpty : Bool { return dictionary.isEmpty }
  @inlinable var first   : (key: Key, value: Value)? { return dictionary.first }

  @inlinable
  var underestimatedCount: Int { return dictionary.underestimatedCount }

  @inlinable var count: Int { return dictionary.count }
  
  // MARK: - Dynamic Member Lookup
  
  @inlinable
  subscript(dynamicMember k: String) -> Value? { return dictionary[k] }
}

extension ExpressWrappedDictionary: CustomStringConvertible {
  
  public var description: String {
    dictionary.description
  }
}

public extension ExpressWrappedDictionary {

  @inlinable
  subscript(int key: Key) -> Int? {
    guard let v = self[key] else { return nil }
    if let i = (v as? Int) { return i }
    #if swift(>=5.10)
    if let i = (v as? any BinaryInteger) { return Int(clamping: i) }
    #endif
    return Int("\(v)")
  }
  
  @inlinable
  subscript(string key: Key) -> String? {
    guard let v = self[key] else { return nil }
    if let s = (v as? String) { return s }
    return String(describing: v)
  }
}

public extension BodyParserBody {
  
  @inlinable
  static func urlEncoded(_ values: ExpressWrappedDictionary<Any>) -> Self {
    return .urlEncoded(values.dictionary)
  }
}
