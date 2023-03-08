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
    self.reader(ReducerProxy(state: state, action: action)).reduce(into: &state, action: action)
  }
}

// Example of a ReducerProxy (unused)
@dynamicMemberLookup
public struct ReducerProxy<State, Action> {
  public let state: State
  public let action: Action
  @Dependency(\.self) public var dependencies

  @usableFromInline
  init(state: State, action: Action) {
    self.state = state
    self.action = action
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }

  public subscript<Value>(dependency: KeyPath<DependencyValues, Value>) -> Value {
    self.dependencies[keyPath: dependency]
  }
}
