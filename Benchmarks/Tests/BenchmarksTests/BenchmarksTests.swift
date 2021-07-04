import Benchmarks
import LocalTCA
import ReferenceTCA
import XCTest

class BenchmarksTests: XCTestCase {
  func testLocalReductionInDebugMode() {
    measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTMemoryMetric(), XCTClockMetric()]) {
      Benchmarks.benchmarkLargePullbacks()
    }
  }

  func testReferenceReduction() {
    measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTMemoryMetric(), XCTClockMetric()]) {
      ReferenceTCA.benchmarkLargePullbacks()
    }
  }

  func testLocalReduction() {
    measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTMemoryMetric(), XCTClockMetric()]) {
      LocalTCA.benchmarkLargePullbacks()
    }
  }
}
