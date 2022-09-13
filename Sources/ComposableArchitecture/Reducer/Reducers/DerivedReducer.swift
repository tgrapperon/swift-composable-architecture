public struct DerivedReducer<State, Action, ChildState, ChildAction, Base: ReducerProtocol>:
  ReducerProtocol
where Base.State == State, Base.Action == Action {
  @usableFromInline
  let base: Base
  @usableFromInline
  var update: @Sendable (State, inout ChildState) -> Void
  @usableFromInline
  var embed: @Sendable (inout State, ChildState) -> Void

  public init(
    update: @Sendable @escaping (State, inout ChildState) -> Void,
    embed: @Sendable @escaping (inout State, ChildState) -> Void,
    @ReducerBuilder<State, Action> base: () -> Base
  ) {
    self.update = update
    self.embed = embed
    self.base = base()
  }

  public init(
    extract: @Sendable @escaping (State) -> ChildState,
    embed: @Sendable @escaping (inout State, ChildState) -> Void,
    @ReducerBuilder<ChildState, ChildAction> base: () -> Base
  ) {
    self.update = { $1 = extract($0) }
    self.embed = embed
    self.base = base()
  }

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    // Which one is higher cost? Extract state or action?
    //    let derived = DerivedStateUpdate { [parentState = state] childState in
    //      self.update(parentState, &childState)
    //    }
    //    defer {
    //      if let childState = derived.state as? ChildState {
    //        embed(&state, childState)
    //      }
    //    }
    //    var current = DerivedState.stateUpdates
    //    current[ObjectIdentifier(ChildState.self)] = derived
    //    return DerivedState.$stateUpdates.withValue(current) {
    //      base.reduce(into: &state, action: action)
    //    }
    return .none
  }
}

enum DerivedState {
  @usableFromInline
  @TaskLocal static var stateUpdates: [ObjectIdentifier: DerivedStateUpdate] = [:]
  @usableFromInline
  static func derivedState<State>(for state: State.Type) -> DerivedStateUpdate? {
    stateUpdates[ObjectIdentifier(state)]
  }
}

@usableFromInline
final class DerivedStateUpdate: @unchecked Sendable {

  //  @usableFromInline
  //  var state: Any?
  //  @usableFromInline
  //  func dispose(_ state: Any) {
  //    self.state = state
  //  }
  @usableFromInline
  var update: Any
  @usableFromInline
  var embed: Any

  public init<Parent, Child>(
    update: @Sendable @escaping (Parent, inout Child) -> Void,
    embed: @Sendable @escaping (inout Parent, Child) -> Void
  ) {
    self.update = update
    self.embed = embed
  }

  func modify<Parent, Child, Result>(
    parent: inout Parent,
    child: inout Child,
    body: (inout Child) -> Result
  ) -> Result {
    guard
      let update = update as? (Parent, inout Child) -> Void,
      let embed = embed as? (inout Parent, Child) -> Void
    else {
      return body(&child)
    }
    update(parent, &child)
    defer { embed(&parent, child) }
    return body(&child)
  }
}

//extension Optional where Wrapped == DerivedStateUpdate {
//  func modify<Parent, Child, Result>(
//    parent: inout Parent,
//    body: (inout Child) -> Result) -> Result
//  {
//    switch self {
//    case .none:
//      fatalError()
//    case .some(let wrapped):
//      return wrapped.modify(parent: &parent, body: body)
//    }
//  }
//}

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
