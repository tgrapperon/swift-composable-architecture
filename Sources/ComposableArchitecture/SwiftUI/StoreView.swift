import SwiftUI

public protocol ViewStateProtocol: Equatable {
  associatedtype State
  static func isDuplicate(lhs: Self, rhs: Self) -> Bool
  init(_ state: State)
}

extension ViewStateProtocol {
  static func isDuplicate(lhs: Self, rhs: Self) -> Bool {
    lhs == rhs
  }
}

public protocol ViewActionProtocol {
  associatedtype Action
  static func embed(action: Self) -> Action
}

//struct EquatableViewState<State: Equatable>: ViewStateProtocol {
//  let state: State
//  init(_ state: State) {
//    self.state = state
//  }
//  static func isDuplicate(
//    lhs: EquatableViewState<State>, rhs: EquatableViewState<State>
//  ) -> Bool {
//    lhs.state == rhs.state
//  }
//}
//
//struct IdentityViewAction<Action>: ViewActionProtocol {
//  let action: Action
//  static func embed(action: IdentityViewAction<Action>) -> Action {
//    action.action
//  }
//}

extension Store {
  // Needs to return registered ViewStore
  func viewStore<ViewState: ViewStateProtocol>() -> ViewStore<ViewState, Action>
  where ViewState.State == State {
    ViewStore(
      self.scope(state: ViewState.init(_:)),
      removeDuplicates: ViewState.isDuplicate(lhs:rhs:)
    )
  }

  func viewStore() -> ViewStore<
    State, Action
  > where State: Equatable {
    ViewStore(
      self,
      removeDuplicates: ==
    )
  }
}

public protocol StoreView: View {
  associatedtype StoreState
  associatedtype StoreAction
  associatedtype ViewState
  associatedtype ViewAction
  associatedtype ViewBody: View
  var store: Store<StoreState, StoreAction> { get }
  @ViewBuilder
  func body(viewStore: ViewStore<ViewState, ViewAction>) -> ViewBody
}

extension StoreView
where
  ViewBody == Body,
  ViewState == StoreState,
  ViewAction == StoreAction,
  StoreState: Equatable
{
  public typealias State = ViewState
  public var body: Body {
    body(viewStore: store.viewStore())
  }
}

extension StoreView
where
  ViewBody == Body,
  ViewAction == StoreAction,
  ViewState: ViewStateProtocol,
  ViewState.State == StoreState
{
  public typealias State = StoreState
  public var body: Body {
    body(viewStore: store.viewStore())
  }
}
