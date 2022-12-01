import Clocks
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class TwoCountersTests: XCTestCase {
  func testDynamicDomain() async {
    let store = TestStore(
      initialState: .init(),
      reducer: TwoCounters(),
      prepareDependencies: {
        $0.dynamicDomainDelegate.register(
          id: 42,
          reducer: Animations(),
          initialState: Animations.State(),
          view: AnimationsView.init(store:)
        )
      }
    )

    store.exhaustivity = .off
    await store.send(.dynamic(.init(id: 42, Animations.Action.tapped(.init(x: 100, y: 0))))) {
      $0.counter2.count = 100
    }
    
    store.exhaustivity = .on
    await store.send(.counter2(.incrementButtonTapped)) {
      $0.counter2.count = 101
      $0.dynamic = Animations.State(circleCenter: .init(x: 101, y: 0))
    }
  }
}
