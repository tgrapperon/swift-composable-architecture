import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

private let readMe = """
  This application demonstrates how to handle long-living effects, for example notifications from \
  Notification Center, and how to tie an effect's lifetime to the lifetime of the view.

  Run this application in the simulator, and take a few screenshots by going to \
  *Device › Screenshot* in the menu, and observe that the UI counts the number of times that \
  happens.

  Then, navigate to another screen and take screenshots there, and observe that this screen does \
  *not* count those screenshots. The notifications effect is automatically cancelled when leaving \
  the screen, and restarted when entering the screen.
  """

// MARK: - Feature domain

struct LongLivingEffectsSubscription: ReducerProtocol {
  struct State: Equatable {
    @SubscriptionStateOf<Int> var screenshotCount = 0
  }

  enum Action: Equatable {
    case screenshots(SubscriptionActionOf<Int>)
  }

  @Dependency(\.screenshots) var screenshots


  var body: some ReducerProtocolOf<Self> {
    Scope(state: \.$screenshotCount, action: /Action.screenshots) {
      SubscriptionReducer<Int>(to: \.screenshots, id: "Screenshots") { current, _ in
        return current! + 1
      }
    }
    Reduce<State, Action> { state, action in
      switch action {
      case let .screenshots(.onReceive(.success(n))):
        print(n)
        return .none
      case .screenshots:
        return .none
      }
    }
  }
}

// MARK: - Feature view

struct LongLivingEffectsSubscriptionView: View {
  let store: StoreOf<LongLivingEffectsSubscription>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Text("A screenshot of this screen has been taken \(viewStore.screenshotCount ?? 0) times.")
          .font(.headline)

        Section {
          NavigationLink(destination: self.detailView) {
            Text("Navigate to another screen")
          }
        }
      }
      .navigationTitle("Long-living effects")
      .onAppear {
        viewStore.send(.screenshots(.startObserving))
      }
    }
  }

  var detailView: some View {
    Text(
      """
      Take a screenshot of this screen a few times, and then go back to the previous screen to see \
      that those screenshots were not counted.
      """
    )
    .padding(.horizontal, 64)
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - SwiftUI previews

struct EffectsLongLivingSubscription_Previews: PreviewProvider {
  static var previews: some View {
    let appView = LongLivingEffectsView(
      store: Store(
        initialState: LongLivingEffects.State(),
        reducer: LongLivingEffects()
      )
    )

    return Group {
      NavigationView { appView }
      NavigationView { appView.detailView }
    }
  }
}
