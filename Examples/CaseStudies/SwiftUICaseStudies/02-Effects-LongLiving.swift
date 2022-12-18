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

struct LongLivingEffects: ReducerProtocol {
  struct State: Equatable {
    var screenshotCount = 0
  }

  enum Action: Equatable {
    case task
    case userDidTakeScreenshotNotification
  }

  // Access using direct subscripting
  @MainActor
  @Dependency(\.notifications[screenshotsNotification]) var screenshots
  // Or via an helper
  @Dependency(\.screenshotsAlt) var screenshotsAlt
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .task:
      // When the view appears, start the effect that emits when screenshots are taken.
      return .run { @MainActor send in
        for await _ in self.screenshots() {
          send(.userDidTakeScreenshotNotification)
        }
      }

    case .userDidTakeScreenshotNotification:
      state.screenshotCount += 1
      return .none
    }
  }
}

@MainActor
let screenshotsNotification = NotificationDependency(UIApplication.userDidTakeScreenshotNotification)

// This is not required. Makes tests easiers
extension DependencyValues {
  public var screenshotsAlt: NotificationStream<Void> {
    get { self.notifications[screenshotsNotification] }
    set { self.notifications[screenshotsNotification] = newValue }
  }
}

// MARK: - Feature view

struct LongLivingEffectsView: View {
  let store: StoreOf<LongLivingEffects>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Text("A screenshot of this screen has been taken \(viewStore.screenshotCount) times.")
          .font(.headline)

        Section {
          NavigationLink(destination: self.detailView) {
            Text("Navigate to another screen")
          }
        }
      }
      .navigationTitle("Long-living effects")
      .task { await viewStore.send(.task).finish() }
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

struct EffectsLongLiving_Previews: PreviewProvider {
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
