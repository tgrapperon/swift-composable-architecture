public struct DerivedReducer<State, Action, ChildState, ChildAction, Child: ReducerProtocol>:
  ReducerProtocol
{
  let child: Child
  var extract: (State) -> ChildState
  var embed: (inout State, ChildState) -> Void
  init(
    extract: @escaping (State) -> ChildState,
    embed: @escaping (inout State, ChildState) -> Void,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child
  ) {
    self.extract = extract
    self.embed = embed
    self.child = child()
  }
  
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    // Which one is higher cost? Extract state or action?
    var childState = extract(state)
//    let effects = child.reduce(into: &<#T##Child.State#>, action: <#T##Child.Action#>)
    return .none
  }

//  public var body: some ReducerProtocol<State, Action> {
//    _Observe { state, action in
////      StateWriterReducer { $0 = self.extract(state) }
//      child
//    }
//  }
}

public struct StateWriterReducer<State, Action>: ReducerProtocol {
  
  @usableFromInline
  init(write: @escaping (inout State) -> Void) {
    self.write = write
  }
  
  @usableFromInline
  var write: (inout State) -> Void
  
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    write(&state)
    return Effect.ignored
  }
}
