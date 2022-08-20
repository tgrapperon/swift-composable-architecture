import SwiftUI

// MARK: - Common Helpers -
@available(iOS 16.0, *)
extension NavigationPath { // RandomAccessCollection-like
  var _startIndex: Int { 0 }
  var _endIndex: Int { count }
  
  /// We opt in for throwing functions instead of subscripts. This also makes room for an
  /// hypothetical `inout` cache argument.
  func get(at position: Int) throws -> Any {
    var copy = self
    copy.removeLast(count - (position + 1))
    return try copy.lastComponent!
  }
  
  mutating func set(_ newValue: Any, at position: Int) throws {
    // Auto-register the mangled type name
    registerValueForNavigationPathComponent(newValue)
    // We preserve the tail (position+1)...
    var tail = [Any]()
    while count > position + 1 {
      // Because `lastComponent == nil <=> isEmpty`, we can force-unwrap:
      tail.append(try lastComponent!)
      removeLast()
    }
    // Discard the one that will be replaced:
    if !isEmpty {
      removeLast()
    }
    // Double parenthesis are required by the current version of Swift
    // See https://github.com/apple/swift/issues/59985
    append((newValue as! any (Hashable & Codable)))
    // Restore the tail that was preserved:
    for preserved in tail.reversed() {
      append((preserved as! any (Hashable & Codable)))
    }
  }
}

@available(iOS 16.0, *)
extension NavigationPath { // RangeReplaceableCollection+MutableCollection-like
  mutating func _replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) throws
  where C : Collection, Any == C.Element {
    // Auto-register the mangled type name
    if let first = newElements.first {
      registerValueForNavigationPathComponent(first)
    }
    // We apply the same trick than for the index setter.
    var tail = [Any]()
    while count > subrange.upperBound {
      tail.append(try lastComponent!)
      removeLast()
    }
    // We don't need to preserve this part which will be replaced:
    while count > subrange.lowerBound {
      removeLast()
    }
    // Insert the new elements:
    for newValue in newElements {
      append((newValue as! any (Hashable & Codable)))
    }
    // Restore the preserved tail:
    for preserved in tail.reversed() {
      append((preserved as! any (Hashable & Codable)))
    }
  }
}
@available(iOS 16.0, *)
extension NavigationPath {
  public struct Inspectable: RandomAccessCollection, RangeReplaceableCollection, MutableCollection {
    
    public var navigationPath: NavigationPath
    
    public init(_ navigationPath: NavigationPath) {
      self.navigationPath = navigationPath
    }
    
    public init() {
      self.navigationPath = .init()
    }
    
    public var startIndex: Int { navigationPath._startIndex }
    public var endIndex: Int { navigationPath._endIndex }
    
    public subscript(position: Int) -> Any {
      get {
        do {
          return try navigationPath.get(at: position)
        } catch {
          NavigationPath.printExtractionError(error)
        }
      }
      set {
        do {
          try navigationPath.set(newValue, at: position)
        } catch {
          NavigationPath.printExtractionError(error)
        }
      }
    }
    
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C : Collection, Any == C.Element {
      do {
        try navigationPath._replaceSubrange(subrange, with: newElements)
      } catch {
        NavigationPath.printExtractionError(error)
      }
    }
    /// A throwing version of `last`
    public var lastComponent: Any? {
      get throws { try navigationPath.lastComponent }
    }
  }
}
@available(iOS 16.0, *)
extension NavigationPath {
  /// Generates an inspectable representation of the current path.
  public var inspectable: Inspectable { .init(self) }
}
@available(iOS 16.0, *)
extension NavigationPath.Inspectable {
  public struct Of<Component>: RandomAccessCollection, RangeReplaceableCollection, MutableCollection
  where Component: Hashable, Component: Codable {
    
    public var navigationPath: NavigationPath
    
    public init(_ navigationPath: NavigationPath) {
      registerTypeForNavigationPathComponent(Component.self)
      self.navigationPath = navigationPath
    }
    
    public init() {
      registerTypeForNavigationPathComponent(Component.self)
      self.navigationPath = .init()
    }
    
    public var startIndex: Int { navigationPath._startIndex }
    public var endIndex: Int { navigationPath._endIndex }
    
    public subscript(position: Int) -> Component {
      get {
        do {
          return try navigationPath.get(at: position) as! Component
        } catch {
          NavigationPath.printExtractionError(error)
        }
      }
      set {
        do {
          try navigationPath.set(newValue, at: position)
        } catch {
          NavigationPath.printExtractionError(error)
        }
      }
    }
    
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C : Collection, Component == C.Element {
      do {
        try navigationPath._replaceSubrange(subrange, with: newElements.map{ $0 as Any })
      } catch {
        NavigationPath.printExtractionError(error)
      }
    }
    
    /// A throwing version of `last`
    public var lastComponent: Component? {
      get throws { try navigationPath.lastComponent as? Component }
    }
  }
}
@available(iOS 16.0, *)
extension NavigationPath {
  /// Generates a typed inspectable representation of the current path.
  public func inspectable<Component>(of type: Component.Type)
  -> NavigationPath.Inspectable.Of<Component> {
    .init(self)
  }
}
@available(iOS 16.0, *)
// MARK: - Utilities
extension NavigationPath {
  public enum Error: Swift.Error {
    case nonInspectablePath
    case unableToFindMangledName(String)
  }
  /// This is not super efficient, but at least always in sync.
  var lastComponent: Any? {
    get throws {
      guard !isEmpty else { return nil }
      guard let codable else {
        throw Error.nonInspectablePath
      }
      return try JSONDecoder()
        .decode(_LastElementDecoder.self, from: JSONEncoder().encode(codable)).value
    }
  }
  
  static func printExtractionError(_ error: Swift.Error) -> Never {
    fatalError("Failed to extract `NavigationPath component: \(error)")
  }
  
  /// We use this type to decode the two first encoded components.
  private struct _LastElementDecoder: Decodable {
    var value: Any
    init(from decoder: Decoder) throws {
      var container = try decoder.unkeyedContainer()
      let typeName = try container.decode(String.self)
      typesRegisterLock.lock()
      let mangledTypeName = typeNameToMangled[typeName, default: typeName]
      typesRegisterLock.unlock()
      
      guard let type = _typeByName(mangledTypeName) as? (any Decodable.Type)
      else {
        typesRegisterLock.lock()
        defer { typesRegisterLock.unlock() }
        if typeNameToMangled[typeName] == nil {
          throw Error.unableToFindMangledName(typeName)
        }
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "\(typeName) is not decodable."
        )
      }
      let encodedValue = try container.decode(String.self)
      self.value = try JSONDecoder().decode(type, from: Data(encodedValue.utf8))
    }
  }
}

/// `NavigationPath` codable representation is using `_typeName` instead of mangled names, likely
/// because it is intented to be serialized. But we need mangled names to respawn types using
/// `_typeByName`.
/// I don't know a way to find the mangled name from the type name. If one could generate a list
/// of mangled symbols, we can probably lookup. In the meantime, clients of `Inspectable` should
/// register types they intend to use as path components. This step is realized automatically for
/// `NavigationPath.Inspectable.Of<Component>`, and also automatically when editing the
/// `NavigationPath` using the inspector, but it needs to be performed manually if some
/// `NavigationPath` is deserialized.
///
/// In other words, registering is only required when deserializing an heterogenous
/// `NavigationPath` or an homogenous one with untyped inspection.

/// Register a type for inspection
@available(iOS 14.0, *)
public func registerTypeForNavigationPathComponent<T>(_ type: T.Type) {
  typesRegisterLock.lock()
  typeNameToMangled[_typeName(T.self)] = _mangledTypeName(T.self)
  typesRegisterLock.unlock()
}
// Register a type for inspection from any value of it
@available(iOS 14.0, *)
public func registerValueForNavigationPathComponent(_ value: Any) {
  let type = type(of: value)
  typesRegisterLock.lock()
  typeNameToMangled[_typeName(type)] = _mangledTypeName(type)
  typesRegisterLock.unlock()
}
private let typesRegisterLock = NSRecursiveLock()
private var typeNameToMangled = [String: String]()

//// MARK: - Tests
//func runPseudoTests() {
//  do {
//    // Check extracting the last component
//    let path = NavigationPath([0,1,2,3,4,5,6,7,8,9])
//    assert(path.inspectable.last as? Int == 9)
//  }
//  do {
//    // Check extracting the nth component
//    let path = NavigationPath([0,1,2,3,4,5,6,7,8,9])
//    assert(path.inspectable[4] as? Int == 4)
//  }
//  do {
//    // Check setting the nth component
//    var path = NavigationPath([0,1,2,3,4,5,6,7,8,9]).inspectable
//    path[4] = -1
//    let expected = NavigationPath([0,1,2,3,-1,5,6,7,8,9])
//    assert(path.navigationPath == expected)
//  }
//
//  do {
//    // Check joining two paths
//    let path = NavigationPath([0,1,2,3,4,5,6,7,8,9])
//    let p1 = NavigationPath([0,1,2,3,4])
//    let p2 = NavigationPath([5,6,7,8,9])
//    let joinedPath = (p1.inspectable + p2.inspectable).navigationPath
//    assert(path == joinedPath)
//  }
//
//  do {
//    // Check editing a path "in the belly".
//    var inspectable = NavigationPath([0,1,2,3,4,5,6,7,8,9]).inspectable
//    inspectable.replaceSubrange(3..<6, with: [-1, -2])
//    let expected = NavigationPath([0,1,2,-1,-2,6,7,8,9])
//    assert(expected == inspectable.navigationPath)
//  }
//}
