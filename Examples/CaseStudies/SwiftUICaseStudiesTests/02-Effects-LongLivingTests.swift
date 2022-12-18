import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class LongLivingEffectsTests: XCTestCase {
  func testReducer() async {
    let store = TestStore(
      initialState: LongLivingEffects.State(),
      reducer: LongLivingEffects()
    )
    
    store.dependencies.notifications[screenshotsNotification] = screenshotsNotification.controllable

    let task = await store.send(.task)

    // Simulate a screenshot being taken
    await store.dependencies.notifications[screenshotsNotification].send(())

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    // Simulate screen going away
    await task.cancel()

    // Simulate a screenshot being taken to show no effects are executed.
    await store.dependencies.notifications[screenshotsNotification].send(())

  }
}
