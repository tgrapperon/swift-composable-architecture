@resultBuilder
public enum ReducerBuilder<State, Action> {
  @inlinable
  public static func buildExpression<R: ReducerProtocol<State, Action>>(
    _ expression: R
  ) -> R where R.Body == R {
    expression
  }

  @inlinable
  public static func buildExpression<R: ReducerProtocol<State, Action>>(
    _ expression: R
  ) -> R {
    expression
  }

  @inlinable
  public static func buildBlock() -> EmptyReducer<State, Action> {
    .init()
  }

  public static func buildBlock<R: ReducerProtocol<State, Action>>(_ component: R)
    -> R
  {
    component
  }

  @inlinable
  public static func buildPartialBlock<R: ReducerProtocol<State, Action>>(first: R)
    -> R
  {
    first
  }

  @inlinable
  public static func buildPartialBlock<
    R0: ReducerProtocol<State, Action>, R1: ReducerProtocol<State, Action>
  >(accumulated: R0, next: R1) -> Sequence<R0, R1> {
    .init(r0: accumulated, r1: next)
  }

  // These overloads should bypass EmptyReducer's if overloading is respeced with buildPartialBlock.
  @inlinable
  public static func buildPartialBlock<
    R1: ReducerProtocol<State, Action>
  >(accumulated: EmptyReducer<State, Action>, next: R1) -> R1 {
    next
  }

  @inlinable
  public static func buildPartialBlock<
    R0: ReducerProtocol<State, Action>
  >(accumulated: R0, next: EmptyReducer<State, Action>) -> R0 {
    accumulated
  }

  @inlinable
  public static func buildPartialBlock(
    accumulated: EmptyReducer<State, Action>, next: EmptyReducer<State, Action>
  ) -> EmptyReducer<State, Action> {
    EmptyReducer<State, Action>()
  }

  public struct Sequence<R0: ReducerProtocol, R1: ReducerProtocol>: ReducerProtocol
  where R0.State == R1.State, R0.Action == R1.Action {
    @usableFromInline
    let r0: R0

    @usableFromInline
    let r1: R1

    @usableFromInline
    init(r0: R0, r1: R1) {
      self.r0 = r0
      self.r1 = r1
    }

    @inlinable
    public func reduce(into state: inout R0.State, action: R0.Action) -> Effect<R0.Action, Never> {
      .merge(
        self.r0.reduce(into: &state, action: action),
        self.r1.reduce(into: &state, action: action)
      )
    }
  }

  public static func buildOptional<R: ReducerProtocol<State, Action>>(
    _ component: R?
  ) -> _Either<R, EmptyReducer<State, Action>> {
    if let component = component {
      return .first(component)
    } else {
      return .second(.init())
    }
  }

  public static func buildEither<
    R1: ReducerProtocol<State, Action>, R2: ReducerProtocol<State, Action>
  >(first component: R1) -> _Either<R1, R2> {
    .first(component)
  }

  public static func buildEither<
    R1: ReducerProtocol<State, Action>, R2: ReducerProtocol<State, Action>
  >(second component: R2) -> _Either<R1, R2> {
    .second(component)
  }

  public static func buildLimitedAvailability<R: ReducerProtocol<State, Action>>(
    _ component: R
  ) -> R {
    component
  }
}


