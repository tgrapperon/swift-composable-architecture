@_implementationOnly import ComposableArchitecture

public func performReduction() {
  enum Action {
    case append
  }
  let reducer = Reducer<String, Action, Void> {
    state, _, _ in
    state.append("x")
    return .none
  }

  let store = Store<String, Action>(initialState: "abc", reducer: reducer, environment: ())
  let viewStore = ViewStore(store)
  for _ in 0 ... 100_000 {
    viewStore.send(.append)
  }
}
