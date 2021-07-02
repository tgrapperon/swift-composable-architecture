import LocalTCA
import ReferenceTCA
import XCTest

class BenchmarksTests: XCTestCase {
  func testReferenceReduction() {
    measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTClockMetric()]) {
      ReferenceTCA.performReduction()
    }
  }

  func testLocalReduction() {
    measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTClockMetric()]) {
      LocalTCA.performReduction()
    }
  }
}
