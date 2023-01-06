import SwiftUI

public protocol ViewStateOf<State> {
  associatedtype State
  init(_ state: State)
  init(state: State)
}

extension ViewStateOf {
  public init(_ state: State) {
    self.init(state: state)
  }
  public init(state: State) {
    self.init(state)
  }
}

private enum WithTaskLocalState {
  @TaskLocal static var state: Any?
}
private enum WithTaskLocalBindingViewStore {
  @TaskLocal static var store: Any?
}

func withTaskLocalState<State, ChildState>(_ operation: @escaping (State) -> ChildState) -> (State) ->
  ChildState
{
  if (ChildState.self as Any) is any ViewStateOf.Type {
    return { state in
      WithTaskLocalState.$state.withValue(state) {
        operation(state)
      }
    }
  }
  return operation
}

func withTaskLocalBindingViewStore<State, ChildState>(_ bindingViewStore: BindingViewStore<State>, _ operation: @escaping (BindingViewStore<State>) -> ChildState) ->
ChildState
{
  WithTaskLocalBindingViewStore.$store.withValue(bindingViewStore) {
    operation(bindingViewStore)
  }
}

@propertyWrapper
public struct ObservedValue<State, Value> {
  var value: Value?
  public var wrappedValue: Value {
    value!
  }
  public init(_ transform: (State) -> Value) {
    if let localState = WithTaskLocalState.state as? State {
      self.value = transform(localState)
    }
  }
}

@propertyWrapper
public struct ObservedBindingValue<State, Value: Equatable> {
  enum Storage: Equatable {
    case keyPath(Value, WritableKeyPath<State, BindingState<Value>>)
    case bindingViewState(BindingViewState<Value>)
  }
  let storage: Storage
  public var wrappedValue: Value {
    switch storage {
    case let .bindingViewState(bindingViewState):
      return bindingViewState.wrappedValue
    case let .keyPath(value, _):
      return value
    }
  }
  public var projectedValue: Self { self }
  public init(_ keyPath: WritableKeyPath<State, BindingState<Value>>) {
    if let bindingViewStore = WithTaskLocalBindingViewStore.store as? BindingViewStore<State> {
      let bindingViewState = bindingViewStore.bindingViewState(keyPath: keyPath)
      self.storage = .bindingViewState(bindingViewState)
    } else if let localState = WithTaskLocalState.state as? State {
      self.storage = .keyPath(localState[keyPath: keyPath].wrappedValue, keyPath)
    } else {
      fatalError()
    }
  }
}

extension ObservedValue: Equatable where Value: Equatable {}
extension ObservedBindingValue: Equatable where Value: Equatable {}

extension ViewStateOf {
  public typealias Observe<Value> = ObservedValue<State, Value>
  public typealias Bind<Value: Equatable> = ObservedBindingValue<State, Value>
}

extension ViewStore {
  public subscript<Value: Equatable>(
    dynamicMember keyPath: KeyPath<ViewState, ObservedBindingValue<ViewAction.State, Value>>
  ) -> Binding<Value> where ViewAction: BindableAction {
    let observed = self.state[keyPath: keyPath]
    switch observed.storage {
    case let .bindingViewState(bindingViewState):
      return bindingViewState.binding
    case let .keyPath(_, stateKeyPath):
      return self.binding(
        get: { $0[keyPath: keyPath].wrappedValue },
        send: { newValue in
          .set(stateKeyPath, newValue)
        }
      )
    }
  }
}
