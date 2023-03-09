import Dependencies

/// A reducer that builds a reducer from the current state and action.
public struct ReducerReader<State, Action, Reader: ReducerProtocol>: ReducerProtocol
where Reader.State == State, Reader.Action == Action {
  @usableFromInline
  let reader: (ReducerProxy<State, Action>) -> Reader

  /// Initializes a reducer that builds a reducer from the current state and action.
  ///
  /// - Parameter reader: A reducer builder that has access to the current state and action.
  @inlinable
  public init(
    @ReducerBuilder<State, Action> _ reader: @escaping (ReducerProxy<State, Action>) ->
      Reader
  ) {
    self.init(internal: reader)
  }

  @usableFromInline
  init(internal reader: @escaping (ReducerProxy<State, Action>) -> Reader) {
    self.reader = reader
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    let proxy = ReducerProxy(state: state, action: action)
    return self.reader(proxy).reduce(into: &state, action: action)
  }
}

enum LocalReducerProxy {
  @TaskLocal static var _proxy: Any? = nil
  static func proxy<State, Action>() -> ReducerProxy<State, Action>? {
    proxy(of:ReducerProxy<State, Action>.self)
  }
  static func proxy<T>(of: T.Type) -> T? {
    self._proxy as? T
  }
}

public struct ReducerProxy<State, Action> {
  public let _state: State
  public let _action: Action
  
  public var state: State {
    LocalReducerProxy.proxy(of: Self.self)?._state ?? self._state
  }
  public var action: Action {
    LocalReducerProxy.proxy(of: Self.self)?._action ?? self._action
  }
  
  public func run(_ build: @escaping () -> EffectTask<Action>) -> AlwaysReducer<State, Action> {
    return AlwaysReducer(build)
  }
  
  @_disfavoredOverload
  public func run(_ build: @escaping () -> Void) -> AlwaysReducer<State, Action> {
    AlwaysReducer {
      build()
      return .none
    }
  }
  
  @Dependency(\.self) public var dependencies

  @usableFromInline
  init(state: State, action: Action) {
    self._state = state
    self._action = action
  }
}

public struct AlwaysReducer<State, Action>: ReducerProtocol {
  public let effect: () -> EffectTask<Action>
  @usableFromInline
  init(_ effect: @escaping () -> EffectTask<Action>) {
    self.effect = effect
  }
  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    let proxy = ReducerProxy(state: state, action: action)
    return LocalReducerProxy.$_proxy.withValue(proxy) {
      self.effect()
    }
  }
}


