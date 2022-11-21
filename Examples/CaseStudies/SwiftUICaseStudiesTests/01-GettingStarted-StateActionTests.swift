import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class StateActionTests: XCTestCase {
  func testStateAction() async {
    let store = TestStore(
      initialState: StateActionDemo.State(),
      reducer: StateActionDemo()
    )
    
    store.dependencies.withRandomNumberGenerator = .init(LCRNG())
    
    await store.send(.userDidTapRandomButton) {
      $0.randomValue = 0
      $0.signal = .scrollTo(0)
    }
    
    await store.send(.userDidTapRandomButton) {
      $0.randomValue = 19
      $0.signal = .scrollTo(19)
    }
    
    await store.send(.userDidTapRandomButton) {
      $0.randomValue = 42
      $0.signal = .scrollTo(42)
    }
  }
}

/// A linear congruential random number generator.
struct LCRNG: RandomNumberGenerator {
  var seed: UInt64

  init(seed: UInt64 = 0) {
    self.seed = seed
  }

  mutating func next() -> UInt64 {
    self.seed = 2_862_933_555_777_941_757 &* self.seed &+ 3_037_000_493
    return self.seed
  }
}
