import Dependencies

/// A reducer that builds a reducer from the current state and action.
public struct ReducerReader<State, Action, Reader: ReducerProtocol>: ReducerProtocol
where Reader.State == State, Reader.Action == Action {
  @usableFromInline
  let reader: (StateProxy<State>, Action) -> Reader

  /// Initializes a reducer that builds a reducer from the current state and action.
  ///
  /// - Parameter reader: A reducer builder that has access to the current state and action.
  @inlinable
  public init(
    @ReducerBuilder<StateProxy<State>, Action> _ reader: @escaping (StateProxy<State>, Action) ->
      Reader
  ) {
    self.init(internal: reader)
  }

  @usableFromInline
  init(internal reader: @escaping (StateProxy<State>, Action) -> Reader) {
    self.reader = reader
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    self.reader(StateProxy(state), action).reduce(into: &state, action: action)
  }
}

@dynamicMemberLookup
public struct StateProxy<State> {
  public let value: State
  @Dependency(\.self) var dependencies
  
  @usableFromInline
  init(_ state: State) {
    self.value = state
  }
  
  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.value[keyPath: keyPath]
  }
  
  public subscript<Value>(dependency: KeyPath<DependencyValues, Value>) -> Value {
    self.dependencies[keyPath: dependency]
  }
}
