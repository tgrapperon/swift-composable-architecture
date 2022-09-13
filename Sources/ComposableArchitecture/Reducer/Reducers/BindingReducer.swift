import SwiftUI

/// A reducer that updates bindable state when it receives binding actions.
public struct BindingReducer<State, Action>: ReducerProtocol
where Action: BindableAction, State == Action.State {
  /// Initializes a reducer that updates bindable state when it receives binding actions.
  @inlinable
  public init() {}

  @inlinable
  public func reduce(
    into state: inout State, action: Action
  ) -> Effect<Action, Never> {
    guard let bindingAction = (/Action.binding).extract(from: action)
    else { return .ignored }

    bindingAction.set(&state)
    return .none
  }
}
