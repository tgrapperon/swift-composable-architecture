import OrderedCollections
import SwiftUI

/// A Composable Architecture-friendly wrapper around `ForEach` that simplifies working with
/// collections of state.
///
/// ``ForEachStore`` loops over a store's collection with a store scoped to the domain of each
/// element. This allows you to extract and modularize an element's view and avoid concerns around
/// collection index math and parent-child store communication.
///
/// For example, a todos app may define the domain and logic associated with an individual todo:
///
/// ```swift
/// struct TodoState: Equatable, Identifiable {
///   let id: UUID
///   var description = ""
///   var isComplete = false
/// }
/// enum TodoAction {
///   case isCompleteToggled(Bool)
///   case descriptionChanged(String)
/// }
/// struct TodoEnvironment {}
/// let todoReducer = Reducer<TodoState, TodoAction, TodoEnvironment { ... }
/// ```
///
/// As well as a view with a domain-specific store:
///
/// ```swift
/// struct TodoView: View {
///   let store: Store<TodoState, TodoAction>
///   var body: some View { ... }
/// }
/// ```
///
/// For a parent domain to work with a collection of todos, it can hold onto this collection in
/// state:
///
/// ```swift
/// struct AppState: Equatable {
///   var todos: IdentifiedArrayOf<TodoState> = []
/// }
/// ```
///
/// Define a case to handle actions sent to the child domain:
///
/// ```swift
/// enum AppAction {
///   case todo(id: TodoState.ID, action: TodoAction)
/// }
/// ```
///
/// Enhance its reducer using ``Reducer/forEach(state:action:environment:file:fileID:line:)-n7qj``:
///
/// ```swift
/// let appReducer = todoReducer.forEach(
///   state: \.todos,
///   action: /AppAction.todo(id:action:),
///   environment: { _ in TodoEnvironment() }
/// )
/// ```
///
/// And finally render a list of `TodoView`s using ``ForEachStore``:
///
/// ```swift
/// ForEachStore(
///   self.store.scope(state: \.todos, AppAction.todo(id:action:))
/// ) { todoStore in
///   TodoView(store: todoStore)
/// }
/// ```
///
public struct ForEachStore<
  EachState, EachAction, Data: Collection, ID: Hashable, Content: View
>: DynamicViewContent {
  public var data: Data { store.state.value as! Data }
  let content: (Self) -> Content
  @_LazyState var store: Store<IdentifiedArray<ID, EachState>, (ID, EachAction)>
  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent>(
    _ store: Store<IdentifiedArray<ID, EachState>, (ID, EachAction)>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      OrderedSet<ID>, (ID, EachAction),
      ForEach<
        OrderedSet<ID>, ID,
        ScopeView<
          IdentifiedArray<ID, EachState>, (ID, EachAction), EachState, EachAction, EachContent
        >
      >
    >
  {
    #warning("Handle onDisappear")
    self._store = .init(wrappedValue: store)
    self.content = { _ in
      WithViewStore(
        store.scope(state: { $0.ids }),
        removeDuplicates: areOrderedSetsDuplicates
      ) { viewStore in
        ForEach(viewStore.state, id: \.self) {
          id -> ScopeView<
            IdentifiedArray<ID, EachState>, (ID, EachAction), EachState, EachAction, EachContent
          > in
          // NB: We cache elements here to avoid a potential crash where SwiftUI may re-evaluate
          //     views for elements no longer in the collection.
          //
          // Feedback filed: https://gist.github.com/stephencelis/cdf85ae8dab437adc998fb0204ed9a6b
          var element = store.state.value[id: id]!
          ScopeView(
            store: store,
            state: {
              element = $0[id: id] ?? element
              return element
            },
            action: { (id, $0) },
            content: content
          )
        }
      }
    }
  }

  public init<State, Action, EachContent>(
    _ store: Store<State, Action>,
    state: @escaping (State) -> IdentifiedArray<ID, EachState>,
    action: @escaping (ID, EachAction) -> Action,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == IdentifiedArray<ID, EachState>,
    Content == ScopeView<
      IdentifiedArray<ID, EachState>, (ID, EachAction), OrderedSet<ID>, (ID, EachAction),
      WithViewStore<
        OrderedSet<ID>, (ID, EachAction),
        ForEach<
          OrderedSet<ID>, ID,
          ScopeView<
            IdentifiedArray<ID, EachState>, (ID, EachAction), EachState, EachAction, EachContent
          >
        >
      >
    >
  {

    self._store = .init(wrappedValue: store.scope(state: state, action: action))

    self.content = { `self` in
      ScopeView(
        store: self.store, state: \.ids, action: { $0 },
        content: { idsStore in
          WithViewStore(
            idsStore,
            removeDuplicates: areOrderedSetsDuplicates
          ) { viewStore in
            ForEach(viewStore.state, id: \.self) { id in
              // NB: We cache elements here to avoid a potential crash where SwiftUI may re-evaluate
              //     views for elements no longer in the collection.
              //
              // Feedback filed: https://gist.github.com/stephencelis/cdf85ae8dab437adc998fb0204ed9a6b
              var element = self.store.state.value[id: id]!
              ScopeView(
                store: self.store,
                state: {
                  element = $0[id: id] ?? element
                  return element
                },
                action: { (id, $0) },
                content: content
              )
            }
          }
        })
    }
  }

  public var body: some View {
    self.content(self)
  }
}

private func areOrderedSetsDuplicates<ID: Hashable>(lhs: OrderedSet<ID>, rhs: OrderedSet<ID>)
  -> Bool
{
  var lhs = lhs
  var rhs = rhs
  if memcmp(&lhs, &rhs, MemoryLayout<OrderedSet<ID>>.size) == 0 {
    return true
  }
  return lhs == rhs
}
