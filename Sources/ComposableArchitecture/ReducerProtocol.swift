public protocol ReducerProtocol<State, Action> {
  associatedtype State

  associatedtype Action

  associatedtype Body: ReducerProtocol<State, Action>

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never>

  @ReducerBuilder<State, Action>
  var body: Body { get }
}

extension ReducerProtocol where Body == Self {
  @inlinable
  public var body: Body {
    self
  }
}

extension ReducerProtocol {
  @inlinable
  public func reduce(
    into state: inout Body.State, action: Body.Action
  ) -> Effect<Body.Action, Never> {
    self.body.reduce(into: &state, action: action)
  }
}

public struct NeverReducer<State, Action>: ReducerProtocol {
  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    fatalError()
  }
}

/// Execute a condition closure (State, Action) -> T?. If T is not nil, runs `someReducer`, otherwise, runs `noneReducer`
public struct IfLet<
  Value,
  Some: ReducerProtocol<State, Action>,
  None: ReducerProtocol<State, Action>,
  State,
  Action
>: ReducerProtocol {

  public init(
    condition: @escaping (State, Action) -> Value?,
    @ReducerBuilder<State, Action> then someReducer: @escaping (Value) -> Some,
    @ReducerBuilder<State, Action> else noneReducer: () -> None
  ) {
    self.condition = condition
    self.someReducer = someReducer
    self.noneReducer = noneReducer()
  }
  let condition: (State, Action) -> Value?
  let someReducer: (Value) -> Some
  let noneReducer: None

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    if let value = condition(state, action) {
      return someReducer(value).reduce(into: &state, action: action)
    } else {
      return noneReducer.reduce(into: &state, action: action)
    }
  }
}

extension IfLet where None == EmptyReducer<State, Action> {
  public init(
    condition: @escaping (State, Action) -> Value?,
    @ReducerBuilder<State, Action> then someReducer: @escaping (Value) -> Some ) {
    self.condition = condition
    self.someReducer = someReducer
    self.noneReducer = EmptyReducer<State, Action>()
  }
}

public enum _Either<First, Second> {
  case first(First)
  case second(Second)
}

extension _Either: ReducerProtocol
where
  First: ReducerProtocol, Second: ReducerProtocol, First.State == Second.State,
  First.Action == Second.Action
{
  public typealias State = First.State
  public typealias Action = First.Action
  public typealias Body = Self
  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch self {
    case let .first(reducer): return reducer.reduce(into: &state, action: action)
    case let .second(reducer): return reducer.reduce(into: &state, action: action)
    }
  }
}
