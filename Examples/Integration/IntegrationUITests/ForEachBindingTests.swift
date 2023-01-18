import XCTest

@MainActor
final class ForEachBindingTests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() async throws {
    let app = XCUIApplication()
    app.launch()

    app.collectionViews.buttons["ForEachBindingTestCase"].tap()
    app.buttons["Remove last"].tap()

    XCTAssertFalse(app.textFields["C"].exists)
    // Uncomment to check that it didn't use an index out of bounds.
    // XCTAssertFalse(app.staticTexts["TestFailure"].exists)
  }
}
