import SwiftUI

/// A view that safely unwraps a store of optional state in order to show one of two views.
///
/// When the underlying state is non-`nil`, the `then` closure will be performed with a ``Store``
/// that holds onto non-optional state, and otherwise the `else` closure will be performed.
///
/// This is useful for deciding between two views to show depending on an optional piece of state:
///
/// ```swift
/// IfLetStore(
///   store.scope(state: \SearchState.results, action: SearchAction.results),
/// ) {
///   SearchResultsView(store: $0)
/// } else: {
///   Text("Loading search results...")
/// }
/// ```
///
/// And for showing a sheet when a piece of state becomes non-`nil`:
///
/// ```swift
/// .sheet(
///   isPresented: viewStore.binding(
///     get: \.isGameActive,
///     send: { $0 ? .startButtonTapped : .detailDismissed }
///   )
/// ) {
///   IfLetStore(
///     self.store.scope(state: \.detail, action: AppAction.detail)
///   ) {
///     DetailView(store: $0)
///   }
/// }
/// ```
///
public struct IfLetStore<State, Action, Content: View>: View {
  private let content: (Self, ViewStore<State?, Action>) -> Content
  @_LazyState var store: Store<State?, Action>

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of optional
  /// state is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  ///   - elseContent: A view that is only visible when the optional state is `nil`.
  public init<IfContent, ElseContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<ScopeView<State?, Action, State, Action, IfContent>, ElseContent> {
    self._store = .init(wrappedValue: store)
    self.content = { _,  viewStore in
      if var state = viewStore.state {
        return ViewBuilder.buildEither(
          first: ScopeView(
            store: store,
            state: {
              state = $0 ?? state
              return state
            },
            action: { $0 },
            content: ifContent
          )
        )
      } else {
        return ViewBuilder.buildEither(second: elseContent())
      }
    }
  }

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of optional
  /// state is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  public init<IfContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent
  ) where Content == ScopeView<State?, Action, State, Action, IfContent>? {
    self._store = .init(wrappedValue: store)
    self.content = { _, viewStore in
      if var state = viewStore.state {
        return ScopeView(
          store: store,
          state: {
            state = $0 ?? state
            return state
          },
          action: { $0 },
          content: ifContent
        )
      } else {
        return nil
      }
    }
  }
  
  
  public init<ParentState, ParentAction, IfContent, ElseContent>(
    _ store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> State?,
    action: @escaping (Action) -> ParentAction,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<ScopeView<State?, Action, State, Action, IfContent>, ElseContent> {
    self._store = .init(wrappedValue: store.scope(state: state, action: action))
    self.content = { `self`, viewStore in
      if var state = viewStore.state {
        return ViewBuilder.buildEither(
          first: ScopeView(
            store: self.store,
            state: {
              state = $0 ?? state
              return state
            },
            action: { $0 },
            content: ifContent
          )
        )
      } else {
        return ViewBuilder.buildEither(second: elseContent())
      }
    }
  }
  
  public init<ParentState, ParentAction, IfContent>(
    _ store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> State?,
    action: @escaping (Action) -> ParentAction,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent
  ) where Content == ScopeView<State?, Action, State, Action, IfContent>? {
    self._store = .init(wrappedValue: store.scope(state: state, action: action))
    self.content = { `self`, viewStore in
      if var state = viewStore.state {
        return ScopeView(
          store: self.store,
          state: {
            state = $0 ?? state
            return state
          },
          action: { $0 },
          content: ifContent
        )
      } else {
        return nil
      }
    }
  }

  public var body: some View {
    WithViewStore(
      self.store,
      removeDuplicates: { ($0 != nil) == ($1 != nil) },
      content: { self.content(self, $0) }
    )
  }
}
