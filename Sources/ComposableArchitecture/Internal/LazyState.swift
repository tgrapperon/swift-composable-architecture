import SwiftUI
@propertyWrapper
struct LazyState<Object>: DynamicProperty {
  private final class Storage {
    var initially: (() -> Object)!
    lazy var object: Object = initially()
  }
  @State private var storage = Storage()
  init(wrappedValue: @autoclosure @escaping () -> Object) {
    storage.initially = wrappedValue
  }
  var wrappedValue: Object {
    storage.object
  }
}
