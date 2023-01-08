import SwiftUI

public protocol ObservableState<State> {
  associatedtype State
  init(state: State)
}


private enum WithTaskLocal {
  @TaskLocal static var state: Any?
  
}
// We chose  tosupport only `observe` variants of `WithViewStore` and `ViewStore`, as this allows to
// keep this transform on the UI layer. Otherwise, we would need to push it into `store.scope`
// (which is likely not as problematic as it is inelegant).
func withTaskLocalState<Parent, Child>(_ operation: @escaping (Parent) -> Child) -> (Parent) ->
Child
{
  if (Child.self as Any) is any ObservableState.Type {
    return { parent in
      WithTaskLocal.$state.withValue(parent) {
        operation(parent)
      }
    }
  }
  return operation
}


@propertyWrapper
public struct ObservedValue<State, Value> {
  var value: Value?
  public var wrappedValue: Value {
    value!
  }

  // This one activates in `ViewStoreProtocol<State>
  public init(_ transform: (State) -> Value) {
    if let localState = WithTaskLocal.state as? State {
      self.value = transform(localState)
    } else {
      runtimeWarn("This property wrapper should only be used in `ViewState`")
    }
  }
}

extension ObservedValue: Equatable where Value: Equatable {}
//extension ObservedBindingValue: Equatable where Value: Equatable {}

extension ObservableState {
  public typealias Observe<Value> = ObservedValue<State, Value>
//  public typealias Bind<Value: Equatable> = ObservedBindingValue<State, Value>
}
