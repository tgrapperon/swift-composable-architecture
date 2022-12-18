import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class LongLivingEffectsTests: XCTestCase {
  
//  func testReducer() async {
//    let store = TestStore(
//      initialState: LongLivingEffects.State(),
//      reducer: LongLivingEffects()
//    )
//
//    store.dependencies.notifications.screenshots.makeControllable()
//
//    let task = await store.send(.task)
//
//    // Simulate a screenshot being taken
//    store.dependencies.notifications.screenshots.post()
//
//    await store.receive(.userDidTakeScreenshotNotification) {
//      $0.screenshotCount = 1
//    }
//
//    // Simulate screen going away
//    await task.cancel()
//
//    // Simulate a screenshot being taken to show no effects are executed.
//    store.dependencies.notifications.screenshots.post()
//
//  }
  
//  func testReducer2() async {
//    await DependencyValues.withValue(\.notifications.screenshots, .controllable(\.screenshots)) {
//      let store = TestStore(
//        initialState: LongLivingEffects.State(),
//        reducer: LongLivingEffects()
//      )
//
//      let task = await store.send(.task)
//
//      // Simulate a screenshot being taken
//      store.dependencies.notifications.screenshots.post()
//
//      await store.receive(.userDidTakeScreenshotNotification) {
//        $0.screenshotCount = 1
//      }
//
//      // Simulate screen going away
//      await task.cancel()
//
//      // Simulate a screenshot being taken to show no effects are executed.
//      store.dependencies.notifications.screenshots.post()
//    }
//  }
  
  
  func testReducer3() async {
    let store = TestStore(
      initialState: LongLivingEffects.State(),
      reducer: LongLivingEffects().dependency(\.notifications.screenshots, .controllable(\.screenshots))
    )
    
    let task = await store.send(.task)

    // Simulate a screenshot being taken
    store.dependencies.notifications.screenshots.post()

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    // Simulate screen going away
    await task.cancel()

    // Simulate a screenshot being taken to show no effects are executed.
    store.dependencies.notifications.screenshots.post()

  }
}
