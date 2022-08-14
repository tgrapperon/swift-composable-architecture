import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates the basics of the Composable Architecture in an archetypal counter \
  application.

  The domain of the application is modeled using simple data types that correspond to the mutable \
  state of the application and any actions that can affect that state or the outside world.
  """

struct Counter: ReducerProtocol {
  struct State: Equatable {
    var count = 0
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case incrementButtonTapped
    case longRunning
    case longRunningResult(TaskResult<Int>)
    case onDisappear
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    enum LongRunningCancellation {}
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      return .none
    case .incrementButtonTapped:
      state.count += 1
      return .none
    case .longRunning:
      print("longRunning")
      return .fireAndForget {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)
        print("Fire and forget ended")
      }
//      return .task {
//        return await .longRunningResult(
//          .init(catching: {
//            try await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)
//            return 5
//          }))
//      }
//      .cancellable(id: LongRunningCancellation.self)
    case let .longRunningResult(result):
      print("longRunningResult: \(result)")
      return .none
    case .onDisappear:
      print("onDisappear")
      return .cancel(id: LongRunningCancellation.self)
    }
  }
}

struct CounterView: View {
  let store: StoreOf<Counter>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        HStack {
          Button {
            viewStore.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(viewStore.count)")
            .monospacedDigit()

          Button {
            viewStore.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
        Button("Long running task") {
          viewStore.send(.longRunning)
        }
      }
      .onDisappear {
        viewStore.send(.onDisappear)
      }
    }
  }
}

struct CounterDemoView: View {
  let store: StoreOf<Counter>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        CounterView(store: self.store)
          .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Counter demo")
  }
}

struct CounterView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      CounterDemoView(
        store: Store(
          initialState: Counter.State(),
          reducer: Counter()
        )
      )
    }
  }
}
