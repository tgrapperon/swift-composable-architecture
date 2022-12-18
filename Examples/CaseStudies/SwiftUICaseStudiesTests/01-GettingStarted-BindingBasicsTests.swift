import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import XCTest

@testable import SwiftUICaseStudies

extension TestStore {
  public func snapshot() -> Store<State, Action> {
    Store(initialState: self.state, reducer: EmptyReducer())
  }

  func assertSnapshot<Value, Format>(
    _ view: (Store<State, Action>) -> Value,
    as strategy: Snapshotting<Value, Format>,
    named name: String? = nil,
    record recording: Bool = false,
    timeout: TimeInterval = 5,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
  ) {
    SnapshotTesting.assertSnapshot(
      matching: view(snapshot()),
      as: strategy,
      named: name,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }

  func assertSnapshot<Value>(
    _ view: (Store<State, Action>) -> Value,
    as strategy: Snapshotting<Value, UIImage> = .image,
    named name: String? = nil,
    record recording: Bool = false,
    timeout: TimeInterval = 5,
    file: StaticString = #file,
    testName: String = #function,
    line: UInt = #line
  ) where Value: SwiftUI.View {
    SnapshotTesting.assertSnapshot(
      matching: view(snapshot()),
      as: strategy,
      named: name,
      record: recording,
      timeout: timeout,
      file: file,
      testName: testName,
      line: line
    )
  }
}

@MainActor
final class BindingFormTests: XCTestCase {
  func testBasics() async {
    let store = SnapshotTestStore(
      initialState: BindingForm.State(),
      reducer: BindingForm(),
      snapshotValue: BindingFormView.init(store:)
    )
    await store.send(.set(\.$sliderValue, 2)) {
      $0.sliderValue = 2
    }

    await store.send(.set(\.$stepCount, 1)) {
      $0.sliderValue = 1
      $0.stepCount = 1
    }

    await store.send(.set(\.$text, "Blob")) {
      $0.text = "Blob"
    }

    await store.send(.set(\.$toggleIsOn, true)) {
      $0.toggleIsOn = true
    }

    await store.send(.resetButtonTapped) {
      $0 = BindingForm.State(sliderValue: 5, stepCount: 10, text: "", toggleIsOn: false)
    }
  }
}

public final class SnapshotTestStore<
  State, Action, ScopedState, ScopedAction, Environment, SnapshotValue
>: TestStore<State, Action, ScopedState, ScopedAction, Environment> {
  let snapshotValue: (Store<State, Action>) -> SnapshotValue
  public var automaticallyAssertSnapshots: Bool = true
  public init<Reducer>(
    initialState: @autoclosure () -> State,
    reducer: Reducer,
    prepareDependencies: (inout DependencyValues) -> Void = { _ in },
    snapshotValue: @escaping (Store<State, Action>) -> SnapshotValue,
    file: StaticString = #file,
    line: UInt = #line
  )
  where
  Reducer: ReducerProtocol,
    State == Reducer.State,
    Action == Reducer.Action,
    State == ScopedState,
    Action == ScopedAction,
    Environment == Void,
    SnapshotValue: View
  {
    self.snapshotValue = snapshotValue
    super.init(
      initialState: initialState(),
      reducer: reducer,
      prepareDependencies: prepareDependencies,
      file: file,
      line: line
    )
    var count: Int = 0
    self.onTestStoreEvent = { [weak self] event in
      guard let self else { return }
      guard self.automaticallyAssertSnapshots else { return }
      let value = self.snapshotValue(self.snapshot())
      SnapshotTesting.assertSnapshot(
        matching: value,
        as: .image,
        named: "\(count) - Store<\(State.self)/\(Action.self)> - \(event.truncatedDescription)",
        file: file,
        line: line
      )
      count += 1
    }
  }
}
