public struct DerivedStateReducer<State, Action, ChildState, ChildAction, Base: ReducerProtocol>:
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
    var stateUpdates = DerivedState.stateUpdates
    stateUpdates[ObjectIdentifier(ChildState.self)] = DerivedDomainStateUpdate(
      update: self.update,
      embed: self.embed
    )
    return DerivedState.$stateUpdates.withValue(stateUpdates) {
      base.reduce(into: &state, action: action)
    }
  }
}

@usableFromInline
enum DerivedState {
  @usableFromInline
  @TaskLocal static var stateUpdates: [ObjectIdentifier: DerivedDomainStateUpdate] = [:]
  @usableFromInline
  static func `for`<State>(_ state: State.Type) -> DerivedDomainStateUpdate? {
    stateUpdates[ObjectIdentifier(state)]
  }
}

@usableFromInline
final class DerivedDomainStateUpdate: @unchecked Sendable {
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

//extension Optional where Wrapped == DerivedDomainStateUpdate {
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
