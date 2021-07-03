import LocalTCA
import ReferenceTCA
import XCTest
import Benchmarks

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
  
  func testLocalReductionInDebugMode() {
    measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTClockMetric()]) {
      Benchmarks.performReduction()
    }
  }
}
