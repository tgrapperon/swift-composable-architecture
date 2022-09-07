import SwiftUI
@propertyWrapper
public struct _LazyState<Object>: DynamicProperty {
  private final class Storage {
    var initially: (() -> Object)!
    lazy var object: Object = initially()
  }
  @State private var storage = Storage()
  public init(wrappedValue: @autoclosure @escaping () -> Object) {
    storage.initially = wrappedValue
  }
  public var wrappedValue: Object {
    storage.object
  }
}
