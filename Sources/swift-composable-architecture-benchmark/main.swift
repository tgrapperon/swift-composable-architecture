import Benchmark
import ComposableArchitecture

do {
  struct State: Equatable {
    @BindableState var value: Int = 0
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  do {
    let bindingReducer = EmptyReducer<State, Action>().binding()
    let store = Store(initialState: .init(), reducer: Reducer(bindingReducer), environment: ())
    let viewStore = ViewStore(store)
    benchmark("Binding") {
      viewStore.send(.set(\.$value, 1))
    }
  }
  
  do {
    let bindingReducer = EmptyReducer<State, Action>().bindingWithBody()
    let store = Store(initialState: .init(), reducer: Reducer(bindingReducer), environment: ())
    let viewStore = ViewStore(store)
    benchmark("Binding with body") {
      viewStore.send(.set(\.$value, 1))
    }
  }
}

Benchmark.main()
