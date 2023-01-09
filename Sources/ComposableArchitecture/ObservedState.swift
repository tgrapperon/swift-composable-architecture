import SwiftUI

public protocol ObservableState<State> {
  associatedtype State
  init(state: State)
}

// ObservableState is required to get autocompletion for the keyPath in the two specialized
// typaliases below:
extension ObservableState {
  public typealias Observe<Value> = _ObservedValue<State, Value>
  public typealias Bind<Value: Equatable> = _ObservedBindingValue<State, Value>
}

// End of public APIs

private enum WithTaskLocal {
  @TaskLocal static var state: Any?
  @TaskLocal static var bindingViewStore: Any?
}

// We chose to support only `observe` variants of `WithViewStore` and `ViewStore`, as this allows to
// keep this transform on the UI layer. Otherwise, we would need to push it into `store.scope`
// (which is likely not as problematic as it is inelegant). I made the change in `store.scope to
// demonstrate where it would be required, but it should be removed without issues, as `WithViewStore`
// and `ViewStore` init have already been updated to perform the operation automatically.
func withTaskLocalState<ParentState, ChildState>(_ operation: @escaping (ParentState) -> ChildState)
  -> (ParentState) -> ChildState
{
  if ChildState.self is any ObservableState.Type {
    return { parentState in
      WithTaskLocal.$state.withValue(parentState) {
        operation(parentState)
      }
    }
  }
  return operation
}

// Note: Debug context should be reworked: `fileID` is used for `file` in
// WithViewStore`, and nothing is used in `ViewStore`.
func withTaskLocalBindingViewStore<ParentState, ParentAction, ChildState, ChildAction>(
  store: Store<ParentState, ParentAction>,
  send fromViewAction: @escaping (ChildAction) -> ParentAction,
  _ operation: @escaping (ParentState) -> ChildState,
  file: StaticString = #file,
  fileID: StaticString = #fileID,
  line: UInt = #line
) -> (ParentState) -> ChildState {
  guard
    let bindingStore = store.bindingStore(send: fromViewAction),
    let bindingViewStore = BindingViewStore(
      store: bindingStore,
      file: file,
      fileID: fileID,
      line: line
    )
  else {
    return operation
  }
  return { parentState in
    WithTaskLocal.$bindingViewStore.withValue(bindingViewStore) {
      operation(parentState)
    }
  }
}

extension Store {
  fileprivate func bindingStore<ViewAction>(
    send fromViewAction: @escaping (ViewAction) -> Action
  ) -> Store<State, ViewAction>? {
    guard
      let bindable = Action.self as? any BindableAction.Type,
      bindable.isBinding(State.self)
    else { return nil }
    return self.scope(state: { $0 }, action: fromViewAction)
  }
}

extension BindingViewStore {
  fileprivate init?<Action>(
    store: Store<State, Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    guard
      let bindable = Action.self as? any BindableAction.Type,
      let action = bindable.castBinding(
        state: State.self,
        action: Action.self
      )
    else { return nil }

    self.store = store.scope(state: { $0 }, action: action)
    #if DEBUG
      self.bindableActionType = type(of: Action.self)
      self.file = file
      self.fileID = fileID
      self.line = line
    #endif
  }
}

extension BindableAction {
  fileprivate static func castBinding<S, A>(state: S.Type, action: A.Type) -> (
    (BindingAction<S>) -> A
  )? {
    guard
      S.self == State.self,
      A.self == Self.self
    else { return nil }
    return {
      self.binding($0 as! BindingAction<State>) as! A
    }
  }
  fileprivate static func isBinding<S>(_ state: S.Type) -> Bool {
    S.self == State.self
  }
}

// Property wrappers with unresolved `State`:
@propertyWrapper
public struct _ObservedValue<State, Value> {
  var value: Value
  public var wrappedValue: Value {
    value
  }
  public init(_ transform: (State) -> Value) {
    if let localState = WithTaskLocal.state as? State {
      self.value = transform(localState)
    } else {
      fatalError("This property wrapper should only be used in a `ViewState`")
    }
  }
}

@propertyWrapper
public struct _ObservedBindingValue<State, Value: Equatable> {
  var bindingViewState: BindingViewState<Value>
  public var wrappedValue: Value {
    bindingViewState.wrappedValue
  }

  public var projectedValue: Binding<Value> {
    bindingViewState.binding
  }

  public init(_ keyPath: WritableKeyPath<State, BindingState<Value>>) {
    if let bindingViewStore = WithTaskLocal.bindingViewStore as? BindingViewStore<State> {
      self.bindingViewState = bindingViewStore.bindingViewState(keyPath: keyPath)
    } else {
      // Note: A BindingState requirement could prevent this property
      // wrapper to be built in imcompatible contexts.
      fatalError(
        "This property wrapper should only be used in a `ViewState` of a \"Bindable\" state")
    }
  }
}

extension _ObservedValue: Equatable where Value: Equatable {}
extension _ObservedBindingValue: Equatable where Value: Equatable {}
extension _ObservedValue: Hashable where Value: Hashable {}
extension _ObservedBindingValue: Hashable where Value: Hashable {}
