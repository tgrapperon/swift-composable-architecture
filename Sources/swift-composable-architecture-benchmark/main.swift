import Benchmark
import ComposableArchitecture


/// This study measures the minimal time it takes to reduce a `Void` action
/// by an `EmptyReducer` of a `Void` state.
/// This is likely the lower bound reachable by any reducer.
///
/// name         time       std        iterations
/// ---------------------------------------------
/// Trivial Send 958.000 ns ± 456.01 %     967844 // BufferedActions
/// Trivial Send 1333.000 ns ± 588.04 %    718882 // Array<Action>
do {
  let store = Store(initialState: (), reducer: EmptyReducer<Void, Void>())
  let viewStore = ViewStore(store)
  benchmark("Trivial Send") {
    viewStore.send(())
  }
}


















//let counterReducer = Reduce<Int, Bool> { state, action in
//  if action {
//    state += 1
//  } else {
//    state = 0
//  }
//  return .none
//}

//let store1 = Store(initialState: 0, reducer: counterReducer)
//let store2 = store1.scope { $0 }
//let store3 = store2.scope { $0 }
//let store4 = store3.scope { $0 }

//let viewStore1 = ViewStore(store1)
//let viewStore2 = ViewStore(store2)
//let viewStore3 = ViewStore(store3)
//let viewStore4 = ViewStore(store4)

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

Benchmark.main()
