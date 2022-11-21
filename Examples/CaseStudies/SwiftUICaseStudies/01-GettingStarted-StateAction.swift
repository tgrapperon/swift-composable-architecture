import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to make use the @StateAction property wrapper to produce signals. \
  If you tap the "Random" button the reducer will pick a random number and scroll the list \
  to make it visible.
  """

// MARK: - Feature domain

struct StateActionDemo: ReducerProtocol {
  struct State: Equatable {
    let values: [Int] = Array(0..<50)
    var randomValue: Int = 0
    @StateAction<Signal> var signal
  }

  enum Signal: Equatable {
    case scrollTo(Int)
  }

  enum Action: Equatable {
    case userDidTapRandomButton
  }
  
  @Dependency(\.withRandomNumberGenerator) var withRandomNumberGenerator
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .userDidTapRandomButton:
        withRandomNumberGenerator {
          state.randomValue = state.values.randomElement(using: &$0)!
        }
        state.signal = .scrollTo(state.randomValue)
        return .none
      }
    }
  }
}

// MARK: - Feature view

struct StateActionDemoView: View {
  let store: StoreOf<StateActionDemo>
  var body: some View {
    ScrollViewReader { proxy in
      WithViewStore(self.store, observe: { $0 }) { viewStore in
        ScrollView {
          LazyVStack {
            ForEach(viewStore.values, id: \.self) { value in
              Text("\(value)")
                .padding(8)
                .background(
                  viewStore.randomValue == value
                  ? AnyShapeStyle(Color.orange)
                  : AnyShapeStyle(Color.clear),
                  in: RoundedRectangle(cornerRadius: 8)
                )
            }
          }
        }
        .safeAreaInset(edge: .bottom) {
          Button("Random") {
            viewStore.send(.userDidTapRandomButton)
          }
          .buttonStyle(.borderedProminent)
          .padding(.top)
          .frame(maxWidth: .infinity)
          .background(.ultraThinMaterial)
        }
      }
      .onStateAction(store: store, \.$signal) { signal in
        if case let .scrollTo(value) = signal {
          withAnimation(.spring()) {
            proxy.scrollTo(value, anchor: .center)
          }
        }
      }
    }
    .navigationTitle("StateAction demo")
  }
}

// MARK: - SwiftUI previews
struct StateActionDemo_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      StateActionDemoView(
        store: Store(
          initialState: StateActionDemo.State(),
          reducer: StateActionDemo()
        )
      )
    }
  }
}
