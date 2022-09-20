import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to take small features and compose them into bigger ones using the \
  `pullback` and `combine` operators on reducers, and the `scope` operator on stores.

  It reuses the the domain of the counter screen and embeds it, twice, in a larger domain.
  """

struct TwoCountersState: Equatable {
  var counter1 = CounterState()
  var counter2 = CounterState()
}

enum TwoCountersAction {
  case counter1(CounterAction)
  case counter2(CounterAction)
}

struct TwoCountersEnvironment {}

let twoCountersReducer = Reducer<TwoCountersState, TwoCountersAction, TwoCountersEnvironment>
  .combine(
    counterReducer.pullback(
      state: \TwoCountersState.counter1,
      action: /TwoCountersAction.counter1,
      environment: { _ in CounterEnvironment() }
    ),
    counterReducer.pullback(
      state: \TwoCountersState.counter2,
      action: /TwoCountersAction.counter2,
      environment: { _ in CounterEnvironment() }
    )
  )

struct TwoCountersView: View {
  let store: Store<TwoCountersState, TwoCountersAction>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      WithObservedStore(store) { observedStore in
        HStack {
          Text("Counter 1")
          Spacer()
          CounterView(
            store: observedStore.scope(state: \.counter1, action: TwoCountersAction.counter1).store
          )
        }

        HStack {
          Text("Counter 2")
          Spacer()
          CounterView(
            store: observedStore.scope(state: \.counter2, action: TwoCountersAction.counter2).store
          )
        }
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Two counter demo")
  }
}

struct TwoCountersView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TwoCountersView(
        store: Store(
          initialState: TwoCountersState(),
          reducer: twoCountersReducer,
          environment: TwoCountersEnvironment()
        )
      )
    }
  }
}
