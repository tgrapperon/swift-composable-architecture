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
//  benchmark("Trivial Send") {
//    viewStore.send(())
//  }
}

/// This study measures the time it takes to reducer a reducer with many siblings
/// It compares the time it takes to perform the same work in an inlined way, cheating by
/// discarding `Effect` that we know to be .none. The objective is to near the performance
/// of the inlined case with `LargeReducer`.
///
/// Base implementation, with `Effect.merge` using `Publishers.MergeMany`
/// name                    time         std        iterations
/// ----------------------------------------------------------
/// Large Reducer           39333.000 ns ±  10.02 %      34309
/// Large Reducer - Inlined  3833.000 ns ±  26.85 %     334943
do {
  struct LargeReducer: ReducerProtocol {
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
      Reduce { state, _ in
        state = 1
        return .none
      }
    }
  }
  struct LargeReducerInlined: ReducerProtocol {
    var body: some ReducerProtocol<Int, Void> {
      Reduce { state, action in
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
        state = 1
        return .none
      }
    }
  }
  
  let s1 = Store(initialState: 0, reducer: LargeReducer())
  let s2 = Store(initialState: 0, reducer: LargeReducerInlined())
  let vs1 = ViewStore(s1)
  let vs2 = ViewStore(s2)
  
  benchmark("Large Reducer") {
    vs1.send(())
  }
  
  benchmark("Large Reducer - Inlined") {
    vs2.send(())
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
