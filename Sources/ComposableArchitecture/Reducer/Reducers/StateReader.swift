@dynamicMemberLookup
public struct StateProxy<State> {
  @usableFromInline
  let state: State
  
  @usableFromInline
  init(_ state: State) {
    self.state = state
  }
  
  public subscript <Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    state[keyPath: keyPath]
  }
}

public struct StateReader<Content: ReducerProtocol>: ReducerProtocol {
  public typealias State = Content.State
  public typealias Action = Content.Action
  
  @usableFromInline
  let content: (StateProxy<State>) -> Content
  
  @inlinable
  public init(@ReducerBuilder<State, Action> content: @escaping (StateProxy<State>) -> Content) {
    self.content = content
  }
  
  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    let proxy = StateProxy(state)
    return content(proxy).reduce(into: &state, action: action)
  }
}
