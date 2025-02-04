import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class IdentifiedListTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Identified list"].tap()
    self.clearLogs()
    //SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Add"].tap()
    self.assertLogs {
      """
      BasicsView.body
      IdentifiedListView.body
      IdentifiedListView.body.ForEachStore
      IdentifiedListView.body.ForEachStore
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.scope
      Store<UUID, Action>
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<IdentifiedListView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
      ViewIdentifiedStoreOf<BasicsView.Feature>.deinit
      ViewIdentifiedStoreOf<BasicsView.Feature>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<IdentifiedArray<UUID, BasicsView.Feature.State>, IdentifiedAction<UUID, BasicsView.Feature.Action>>.deinit
      ViewStore<IdentifiedArray<UUID, BasicsView.Feature.State>, IdentifiedAction<UUID, BasicsView.Feature.Action>>.init
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.deinit
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewIdentifiedStoreOf<BasicsView.Feature>.body
      WithViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.body
      WithViewStore<UUID, BasicsView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }

  func testAddTwoIncrementFirst() {
    self.app.buttons["Add"].tap()
    self.app.buttons["Add"].tap()
    self.clearLogs()
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      BasicsView.body
      IdentifiedListView.body
      IdentifiedListView.body.ForEachStore
      IdentifiedListView.body.ForEachStore
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.scope
      IdentifiedStoreOf<BasicsView.Feature>.scope
      Store<UUID, Action>
      Store<UUID, Action>
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.scope
      Store<UUID, BasicsView.Feature.Action>.scope
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
      ViewIdentifiedStoreOf<BasicsView.Feature>.deinit
      ViewIdentifiedStoreOf<BasicsView.Feature>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<IdentifiedArray<UUID, BasicsView.Feature.State>, IdentifiedAction<UUID, BasicsView.Feature.Action>>.deinit
      ViewStore<IdentifiedArray<UUID, BasicsView.Feature.State>, IdentifiedAction<UUID, BasicsView.Feature.Action>>.init
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.deinit
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewIdentifiedStoreOf<BasicsView.Feature>.body
      WithViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.body
      WithViewStore<UUID, BasicsView.Feature.Action>.body
      WithViewStore<UUID, BasicsView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }

  func testAddTwoIncrementSecond() {
    self.app.buttons["Add"].tap()
    self.app.buttons["Add"].tap()
    self.clearLogs()
    self.app.cells.element(boundBy: 2).buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      IdentifiedStoreOf<BasicsView.Feature>.scope
      IdentifiedStoreOf<BasicsView.Feature>.scope
      Store<UUID, BasicsView.Feature.Action>.scope
      Store<UUID, BasicsView.Feature.Action>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
