import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to take small features and compose them into bigger ones using the \
  `pullback` and `combine` operators on reducers, and the `scope` operator on stores.

  It reuses the the domain of the counter screen and embeds it, twice, in a larger domain.
  """

struct TwoCounters: ReducerProtocol {
  struct State: Equatable {
    var counter1 = Counter.State()
    var counter2 = Counter.State()
  }

  enum Action: Equatable {
    case counter1(Counter.Action)
    case counter2(Counter.Action)
  }

  static let counter1 = DomainScope<Counter>(state: \.counter1, action: /Action.counter1)
  static let counter2 = DomainScope<Counter>(state: \.counter2, action: /Action.counter2)

  var body: some ReducerProtocol<State, Action> {
    Scope(Self.counter1) {
      Counter()
    }
    Scope(Self.counter2) {
      Counter()
    }
  }
}

struct TwoCountersView: View {
  let store: StoreOf<TwoCounters>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        Text("Counter 1")
        Spacer()
        CounterView(
          store: self.store.scope(TwoCounters.counter1)
        )
      }

      HStack {
        Text("Counter 2")
        Spacer()
        CounterView(
          store: self.store.scope(TwoCounters.counter2)
        )
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
          initialState: TwoCounters.State(),
          reducer: TwoCounters()
        )
      )
    }
  }
}
