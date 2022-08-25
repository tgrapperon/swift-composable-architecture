import Benchmark
import ComposableArchitecture

let counterReducer = Reduce<Int, Bool> { state, action in
  if action {
    state += 1
  } else {
    state = 0
  }
  return .none
}

let store1 = Store(initialState: 0, reducer: counterReducer)
let store2 = store1.scope { $0 }
let store3 = store2.scope { $0 }
let store4 = store3.scope { $0 }

let viewStore1 = ViewStore(store1)
let viewStore2 = ViewStore(store2)
let viewStore3 = ViewStore(store3)
let viewStore4 = ViewStore(store4)
//
//benchmark("Scoping (1)") {
//  viewStore1.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (2)") {
//  viewStore2.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (3)") {
//  viewStore3.send(true)
//}
//viewStore1.send(false)
//
//benchmark("Scoping (4)") {
//  viewStore4.send(true)
//}
struct ComposedReducer: ReducerProtocol {
  var body: some ReducerProtocol<Int, Void> {
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    EmptyReducer()
    Reduce { state, action in
      state += 1
      return .none
    }
  }
}

struct ComposedInlinedReducer: ReducerProtocol {
  func reduce(into state: inout Int, action: Void) -> Effect<Void, Never> {
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    let _ = EmptyReducer().reduce(into: &state, action: action)
    return Reduce { state, action in
      state += 1
      return .none
    }
    .reduce(into: &state, action: action)
  }
}



do {
  let store = Store(initialState: 0, reducer: ComposedReducer())
  let viewStore = ViewStore(store)

  benchmark("ComposedReducer") {
    viewStore.send(())
  }
}

do {
  let store = Store(initialState: 0, reducer: ComposedInlinedReducer())
  let viewStore = ViewStore(store)

  benchmark("InlinedReducer") {
    viewStore.send(())
  }
}

Benchmark.main()
