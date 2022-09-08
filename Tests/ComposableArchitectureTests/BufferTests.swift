import XCTest

@testable import ComposableArchitecture

final class BufferTests: XCTestCase {
  func testBufferInsertion() {
    var buffer = Buffer<Int>()
    XCTAssertTrue(buffer.isEmpty)
    buffer.append(0)
    XCTAssertFalse(buffer.isEmpty)
    buffer.append(1)
    XCTAssertFalse(buffer.isEmpty)
    
    let first = buffer.removeFirst()
    XCTAssertEqual(first, 0)
    XCTAssertFalse(buffer.isEmpty)

    let second = buffer.removeFirst()
    XCTAssertEqual(second, 1)
    XCTAssertTrue(buffer.isEmpty)
  }
  
  func testBufferSequence() {
    var buffer = Buffer<Int>()
    buffer.append(0)
    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    buffer.append(4)
    XCTAssertEqual(buffer.removeFirst(), 0)
    XCTAssertEqual(buffer.removeFirst(), 1)
    buffer.append(5)
    buffer.append(6)
    XCTAssertEqual(buffer.removeFirst(), 2)
    XCTAssertEqual(buffer.removeFirst(), 3)
    XCTAssertEqual(buffer.removeFirst(), 4)
    buffer.append(7)
    buffer.append(8)
    XCTAssertEqual(buffer.removeFirst(), 5)
    buffer.append(9)
    XCTAssertEqual(buffer.removeFirst(), 6)
    XCTAssertEqual(buffer.removeFirst(), 7)
    XCTAssertEqual(buffer.removeFirst(), 8)
    XCTAssertEqual(buffer.removeFirst(), 9)
    XCTAssertTrue(buffer.isEmpty)
    buffer.append(10)
    XCTAssertEqual(buffer.removeFirst(), 10)
    XCTAssertTrue(buffer.isEmpty)
  }
}
