import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional data into state.

  Tapping "Load optional counter" fires off an effect that will load the counter state a second \
  later. When the counter state is present, you will be programmatically presented a sheet that \
  depends on this data.
  """

// MARK: - Feature domain

struct LoadThenPresent: ReducerProtocol {
  struct State: Equatable {
    @PresentationStateOf<Counter> var counter
    var isActivityIndicatorVisible = false
  }

  enum Action {
    case counter(PresentationActionOf<Counter>)
    case presentationDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter(.present):
        state.isActivityIndicatorVisible = true
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .presentationDelayCompleted
        }

      case .counter:
        return .none

      case .presentationDelayCompleted:
        state.counter = Counter.State()
        state.isActivityIndicatorVisible = false
        return .none
      }
    }
    .presentationDestination(\.$counter, action: /Action.counter) {
      Counter()
    }
  }
}

// MARK: - Feature view

struct LoadThenPresentView: View {
  let store: StoreOf<LoadThenPresent>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        Button {
          viewStore.send(.counter(.present))
        } label: {
          HStack {
            Text("Load optional counter")
            if viewStore.isActivityIndicatorVisible {
              Spacer()
              ProgressView()
            }
          }
        }
      }
      .navigationTitle("Load and present")
      .sheet(
        store: self.store.scope(state: \.$counter, action: LoadThenPresent.Action.counter),
        content: CounterView.init(store:)
      )
    }
  }
}

// MARK: - SwiftUI previews

struct LoadThenPresentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenPresentView(
        store: Store(
          initialState: LoadThenPresent.State(),
          reducer: LoadThenPresent()
        )
      )
    }
  }
}
