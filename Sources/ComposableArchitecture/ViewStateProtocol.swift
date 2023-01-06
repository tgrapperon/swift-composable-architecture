import SwiftUI

public protocol ViewStateProtocol<State> {
  associatedtype State
  init(_ state: State)
  init(state: State)
}

// Doesn't work as `struct ViewState: ViewStateOf<Login>` (or even `ViewStateOf<Login.State>`)
//public typealias BindableViewStateOf<R: ReducerProtocol> = ViewStateProtocol<BindingViewStore<R.State>>
//public typealias ViewStateOf<R: ReducerProtocol> = ViewStateProtocol<R.State>

extension ViewStateProtocol {
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

// Used in Store.scope
func withTaskLocalState<State, ChildState>(_ operation: @escaping (State) -> ChildState) -> (State) ->
  ChildState
{
  if (ChildState.self as Any) is any ViewStateProtocol.Type {
    return { state in
      WithTaskLocalState.$state.withValue(state) {
        operation(state)
      }
    }
  }
  return operation
}

// Used in WithViewStore(_, observe: BindingViewStore<_>, _)
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
  
  // This one activates in `ViewStoreProtocol<State>
  public init(_ transform: (State) -> Value) {
    if let localState = WithTaskLocalState.state as? State {
      self.value = transform(localState)
    } else if let localState = WithTaskLocalState.state as? BindingViewStore<State> {
      self.value = transform(localState.wrappedValue)
    }
  }
  // This one activates in `ViewStoreProtocol<BindingViewStore<State>>
  public init<S>(_ transform: (S) -> Value) where State == BindingViewStore<S> {
    if let localState = WithTaskLocalState.state as? State {
      self.value = transform(localState.wrappedValue)
    } else if let localState = WithTaskLocalState.state as? S {
      self.value = transform(localState)
    }
  }
}

@propertyWrapper
public struct ObservedBindingValue<State, Value: Equatable> {
  var bindingViewState: BindingViewState<Value>
  public var wrappedValue: Value {
    bindingViewState.wrappedValue
  }

  public var projectedValue: Binding<Value> {
    bindingViewState.binding
  }

  public init<S>(_ keyPath: WritableKeyPath<S, BindingState<Value>>) where State == BindingViewStore<S> {
    if let bindingViewStore = WithTaskLocalBindingViewStore.store as? BindingViewStore<S> {
      self.bindingViewState = bindingViewStore.bindingViewState(keyPath: keyPath)
    } else {
      fatalError()
    }
  }
}

extension ObservedValue: Equatable where Value: Equatable {}
extension ObservedBindingValue: Equatable where Value: Equatable {}

extension ViewStateProtocol {
  public typealias Observe<Value> = ObservedValue<State, Value>
  public typealias Bind<Value: Equatable> = ObservedBindingValue<State, Value>
}
