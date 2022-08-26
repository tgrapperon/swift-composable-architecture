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
/// name                    time       std        iterations
/// --------------------------------------------------------
/// Large Reducer           959.000 ns ± 164.36 %     983614
/// Large Reducer - Inlined 958.000 ns ± 113.78 %    1000000
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
  
//  benchmark("Large Reducer") {
//    vs1.send(())
//  }
//  
//  benchmark("Large Reducer - Inlined") {
//    vs2.send(())
//  }
}

do {
  struct R1: ReducerProtocol {
    struct S {
      var s2: R2.S = .init()
    }
    enum A {
      case a2(R2.A)
    }
    var body: some ReducerProtocol<R1.S, R1.A> {
      Scope(state: \.s2, action: /A.a2) {
        R2()
      }
    }
  }
  struct R2: ReducerProtocol {
    struct S {
      var s3: R3.S = .init()
    }
    enum A {
      case a3(R3.A)
    }
    var body: some ReducerProtocol<R2.S, R2.A> {
      Scope(state: \.s3, action: /A.a3) {
        R3()
      }
    }
  }
  struct R3: ReducerProtocol {
    struct S {
      var s4: R4.S = .init()
    }
    enum A {
      case a4(R4.A)
    }
    var body: some ReducerProtocol<R3.S, R3.A> {
      Scope(state: \.s4, action: /A.a4) {
        R4()
      }
    }
  }
  struct R4: ReducerProtocol {
    struct S {
      var s5: R5.S = .init()
    }
    enum A {
      case a5(R5.A)
    }
    var body: some ReducerProtocol<R4.S, R4.A> {
      Scope(state: \.s5, action: /A.a5) {
        R5()
      }
    }
  }
  struct R5: ReducerProtocol {
    struct S: Equatable {
      var value = 0
    }
    enum A {
      case ping
    }
    var body: some ReducerProtocol<R5.S, R5.A> {
      Reduce { state, _ in
        state.value += 1
        return .none
      }
    }
  }
  let s1 = Store(initialState: R1.S(), reducer: R1())
  let s2 = s1.scope(state: \.s2, action: R1.A.a2)
  let s3 = s2.scope(state: \.s3, action: R2.A.a3)
  let s4 = s3.scope(state: \.s4, action: R3.A.a4)
  let s5 = s4.scope(state: \.s5, action: R4.A.a5)

  let vs5 = ViewStore(s5)
  let vs1 = ViewStore(s1.stateless)
  
  benchmark("Scope - Leaf") {
    vs5.send(.ping)
  }
  benchmark("Scope - Root") {
    vs1.send(.a2(.a3(.a4(.a5(.ping)))))
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
