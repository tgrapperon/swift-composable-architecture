import SwiftUI
@propertyWrapper
public struct _LazyState<Object>: DynamicProperty {
  private final class Storage {
    var initially: (() -> Object)!
    lazy var _object: Object? = initially()
    var object: Object {
      if _object == nil { _object = initially() }
      return _object!
    }
  }
  @State private var storage = Storage()
  public init(wrappedValue: @autoclosure @escaping () -> Object) {
    storage.initially = wrappedValue
  }
  public var wrappedValue: Object {
    storage.object
  }
  
  public var projectedValue: Self {
    self
  }
  
  func onDisappear() {
    storage._object = nil
  }
}

// Voice Memo 150 -> 8 scopes
// Todo: 44 -> 8 scopes
// Case Study Animations: 1 scope for the whole feature (without activating .alert)

// Main issue: @State live a little longer that desired, at least when navigating back, so we
// probably need to shut scoped stores down at `onDisappear`.
