import Combine

public protocol _ReducerSequenceProtocol: ReducerProtocol {
  func reduce(into state: inout State, action: Action, accumulated: [Effect<Action, Never>])
    -> [Effect<Action, Never>]
}

extension _ReducerSequenceProtocol {
  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    return .merge(reduce(into: &state, action: action))
  }
}

// Used in `buildPartialBlock(first:` to ensure that at any time `R0` is a
// `_ReducerSequenceProtocol`. This allows to flatten effects inline without checks in
// `reduce(…,accumulated[])`
extension EmptyReducer: _ReducerSequenceProtocol {
  @inlinable
  public func reduce(into state: inout State, action: Action, accumulated: [Effect<Action, Never>])
    -> [Effect<Action, Never>]
  {
    accumulated
  }
}

public struct _ReducerSequenceReducer<S: _ReducerSequenceProtocol>: ReducerProtocol {
  @usableFromInline
  let reducerSequence: S

  @usableFromInline
  init(reducerSequence: S) {
    self.reducerSequence = reducerSequence
  }

  public func reduce(into state: inout S.State, action: S.Action) -> Effect<S.Action, Never> {
    let effects = reducerSequence.reduce(into: &state, action: action, accumulated: [])
    let filtered = effects.filter { !$0.isNone }
    switch filtered.count {
    case 0: return .none
    case 1: return filtered.first!
    default: return .merge(filtered)
    }
  }
}

@resultBuilder
public enum ReducerBuilder<State, Action> {
  public static func buildArray<R: ReducerProtocol>(_ reducers: [R]) -> _SequenceMany<R>
  where R.State == State, R.Action == Action {
    _SequenceMany(reducers: reducers)
  }

  @inlinable
  public static func buildBlock() -> EmptyReducer<State, Action> {
    EmptyReducer()
  }

  @inlinable
  public static func buildBlock<R: ReducerProtocol>(_ reducer: R) -> R
  where R.State == State, R.Action == Action {
    reducer
  }

  @inlinable
  public static func buildEither<R0: ReducerProtocol, R1: ReducerProtocol>(
    first reducer: R0
  ) -> _Conditional<R0, R1>
  where R0.State == State, R0.Action == Action {
    .first(reducer)
  }

  @inlinable
  public static func buildEither<R0: ReducerProtocol, R1: ReducerProtocol>(
    second reducer: R1
  ) -> _Conditional<R0, R1>
  where R1.State == State, R1.Action == Action {
    .second(reducer)
  }

  @inlinable
  public static func buildExpression<R: ReducerProtocol>(_ expression: R) -> R
  where R.State == State, R.Action == Action {
    expression
  }

  @inlinable
  public static func buildFinalResult<R: ReducerProtocol>(_ reducer: R) -> R
  where R.State == State, R.Action == Action {
    reducer
  }

  // Comment this or not to activate the _ReducerSequence branch
  @inlinable
  public static func buildFinalResult<R: _ReducerSequenceProtocol>(_ reducer: R)
  -> _ReducerSequenceReducer<R>
  where R.State == State, R.Action == Action {
    _ReducerSequenceReducer(reducerSequence: reducer)
  }

  #if swift(>=5.7)
    @_disfavoredOverload
    @available(
      *,
      deprecated,
      message:
        """
        Reducer bodies should return 'some ReducerProtocol<State, Action>' instead of 'Reduce<State, Action>'.
        """
    )
    @inlinable
    public static func buildFinalResult<R: ReducerProtocol>(_ reducer: R) -> Reduce<State, Action>
    where R.State == State, R.Action == Action {
      Reduce(reducer)
    }
  #else
    @_disfavoredOverload
    @inlinable
    public static func buildFinalResult<R: ReducerProtocol>(_ reducer: R) -> Reduce<State, Action>
    where R.State == State, R.Action == Action {
      Reduce(reducer)
    }
  #endif

  @inlinable
  public static func buildLimitedAvailability<R: ReducerProtocol>(
    _ wrapped: R
  ) -> _Optional<R>
  where R.State == State, R.Action == Action {
    _Optional(wrapped: wrapped)
  }

  @inlinable
  public static func buildOptional<R: ReducerProtocol>(_ wrapped: R?) -> _Optional<R>
  where R.State == State, R.Action == Action {
    _Optional(wrapped: wrapped)
  }

  @inlinable
  public static func buildPartialBlock<R: ReducerProtocol>(first: R)
    -> _Sequence<EmptyReducer<State, Action>, R>
  where R.State == State, R.Action == Action {
    _Sequence(EmptyReducer(), first)
  }

  @inlinable
  public static func buildPartialBlock<R0: ReducerProtocol, R1: ReducerProtocol>(
    accumulated: R0, next: R1
  ) -> _Sequence<R0, R1>
  where R0.State == State, R0.Action == Action {
    _Sequence(accumulated, next)
  }

  public enum _Conditional<First: ReducerProtocol, Second: ReducerProtocol>: ReducerProtocol
  where
    First.State == Second.State,
    First.Action == Second.Action
  {
    case first(First)
    case second(Second)

    public func reduce(into state: inout First.State, action: First.Action) -> Effect<
      First.Action, Never
    > {
      switch self {
      case let .first(first):
        return first.reduce(into: &state, action: action)

      case let .second(second):
        return second.reduce(into: &state, action: action)
      }
    }
  }

  public struct _Optional<Wrapped: ReducerProtocol>: ReducerProtocol {
    @usableFromInline
    let wrapped: Wrapped?

    @usableFromInline
    init(wrapped: Wrapped?) {
      self.wrapped = wrapped
    }

    @inlinable
    public func reduce(
      into state: inout Wrapped.State, action: Wrapped.Action
    ) -> Effect<Wrapped.Action, Never> {
      switch wrapped {
      case let .some(wrapped):
        return wrapped.reduce(into: &state, action: action)
      case .none:
        return .none
      }
    }
  }

  public struct _Sequence<R0: _ReducerSequenceProtocol, R1: ReducerProtocol>: _ReducerSequenceProtocol
  where R0.State == R1.State, R0.Action == R1.Action {
    @usableFromInline
    let r0: R0

    @usableFromInline
    let r1: R1

    @usableFromInline
    init(_ r0: R0, _ r1: R1) {
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
    @inlinable
    public func reduce(
      into state: inout R0.State, action: R0.Action,
      accumulated: [Effect<R0.Action, Never>]
    ) -> [Effect<R0.Action, Never>] {
      let r0Effects = self.r0.reduce(into: &state, action: action, accumulated: [])
      return accumulated + r0Effects + [self.r1.reduce(into: &state, action: action)]
    }
  }

  public struct _SequenceMany<Element: ReducerProtocol>: _ReducerSequenceProtocol {
    @usableFromInline
    let reducers: [Element]

    @usableFromInline
    init(reducers: [Element]) {
      self.reducers = reducers
    }

    @inlinable
    public func reduce(
      into state: inout Element.State, action: Element.Action
    ) -> Effect<Element.Action, Never> {
      .merge(self.reducers.map { $0.reduce(into: &state, action: action) })
    }

    @inlinable
    public func reduce(
      into state: inout Element.State, action: Element.Action,
      accumulated: [Effect<Element.Action, Never>]
    ) -> [Effect<Element.Action, Never>] {
      accumulated + self.reducers.map { $0.reduce(into: &state, action: action) }
    }
  }
}

public typealias ReducerBuilderOf<R: ReducerProtocol> = ReducerBuilder<R.State, R.Action>

#if swift(<5.7)
  extension ReducerBuilder {
    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1
    ) -> _Sequence<R0, R1>
    where R0.State == State, R0.Action == Action {
      _Sequence(r0, r1)
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2
    ) -> _Sequence<_Sequence<R0, R1>, R2>
    where R0.State == State, R0.Action == Action {
      _Sequence(_Sequence(r0, r1), r2)
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3
    ) -> _Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>
    where R0.State == State, R0.Action == Action {
      _Sequence(_Sequence(_Sequence(r0, r1), r2), r3)
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol,
      R4: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3,
      _ r4: R4
    ) -> _Sequence<_Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>, R4>
    where R0.State == State, R0.Action == Action {
      _Sequence(_Sequence(_Sequence(_Sequence(r0, r1), r2), r3), r4)
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol,
      R4: ReducerProtocol,
      R5: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3,
      _ r4: R4,
      _ r5: R5
    ) -> _Sequence<_Sequence<_Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>, R4>, R5>
    where R0.State == State, R0.Action == Action {
      _Sequence(_Sequence(_Sequence(_Sequence(_Sequence(r0, r1), r2), r3), r4), r5)
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol,
      R4: ReducerProtocol,
      R5: ReducerProtocol,
      R6: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3,
      _ r4: R4,
      _ r5: R5,
      _ r6: R6
    ) -> _Sequence<
      _Sequence<_Sequence<_Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>, R4>, R5>, R6
    >
    where R0.State == State, R0.Action == Action {
      _Sequence(_Sequence(_Sequence(_Sequence(_Sequence(_Sequence(r0, r1), r2), r3), r4), r5), r6)
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol,
      R4: ReducerProtocol,
      R5: ReducerProtocol,
      R6: ReducerProtocol,
      R7: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3,
      _ r4: R4,
      _ r5: R5,
      _ r6: R6,
      _ r7: R7
    ) -> _Sequence<
      _Sequence<_Sequence<_Sequence<_Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>, R4>, R5>, R6>,
      R7
    >
    where R0.State == State, R0.Action == Action {
      _Sequence(
        _Sequence(
          _Sequence(_Sequence(_Sequence(_Sequence(_Sequence(r0, r1), r2), r3), r4), r5), r6
        ),
        r7
      )
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol,
      R4: ReducerProtocol,
      R5: ReducerProtocol,
      R6: ReducerProtocol,
      R7: ReducerProtocol,
      R8: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3,
      _ r4: R4,
      _ r5: R5,
      _ r6: R6,
      _ r7: R7,
      _ r8: R8
    ) -> _Sequence<
      _Sequence<
        _Sequence<
          _Sequence<_Sequence<_Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>, R4>, R5>, R6
        >,
        R7
      >,
      R8
    >
    where R0.State == State, R0.Action == Action {
      _Sequence(
        _Sequence(
          _Sequence(
            _Sequence(_Sequence(_Sequence(_Sequence(_Sequence(r0, r1), r2), r3), r4), r5), r6
          ),
          r7
        ),
        r8
      )
    }

    @inlinable
    public static func buildBlock<
      R0: ReducerProtocol,
      R1: ReducerProtocol,
      R2: ReducerProtocol,
      R3: ReducerProtocol,
      R4: ReducerProtocol,
      R5: ReducerProtocol,
      R6: ReducerProtocol,
      R7: ReducerProtocol,
      R8: ReducerProtocol,
      R9: ReducerProtocol
    >(
      _ r0: R0,
      _ r1: R1,
      _ r2: R2,
      _ r3: R3,
      _ r4: R4,
      _ r5: R5,
      _ r6: R6,
      _ r7: R7,
      _ r8: R8,
      _ r9: R9
    ) -> _Sequence<
      _Sequence<
        _Sequence<
          _Sequence<
            _Sequence<_Sequence<_Sequence<_Sequence<_Sequence<R0, R1>, R2>, R3>, R4>, R5>, R6
          >,
          R7
        >,
        R8
      >,
      R9
    >
    where R0.State == State, R0.Action == Action {
      _Sequence(
        _Sequence(
          _Sequence(
            _Sequence(
              _Sequence(_Sequence(_Sequence(_Sequence(_Sequence(r0, r1), r2), r3), r4), r5), r6
            ),
            r7
          ),
          r8
        ),
        r9
      )
    }
  }
#endif
