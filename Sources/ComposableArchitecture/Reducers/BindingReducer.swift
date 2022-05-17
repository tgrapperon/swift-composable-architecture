import CustomDump
import SwiftUI

#if compiler(>=5.4)
extension ReducerProtocol where Action: BindableAction, State == Action.State {
//  @inlinable
//  public func binding() -> BindingReducer<Self> {
//    .init(upstream: self)
//  }
  // Use `ReducerModifier`:
  @inlinable
  public func binding() -> ModifiedContent<Self, BindingModifier<State, Action>> {
    modifier(BindingModifier())
  }
}

public struct BindingReducer<Upstream: ReducerProtocol>: ReducerProtocol
where Upstream.Action: BindableAction, Upstream.State == Upstream.Action.State {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  init(upstream: Upstream) {
    self.upstream = upstream
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard let bindingAction = (/Upstream.Action.binding).extract(from: action)
    else {
      return self.upstream.reduce(into: &state, action: action)
    }

    bindingAction.set(&state)
    return self.upstream.reduce(into: &state, action: action)
  }
}

public struct BindingModifier<State, Action>: ReducerModifier
where Action: BindableAction, State == Action.State {
  public init() {}
  public func body(content: Content) -> some ReducerProtocol<State, Action> {
    IfLet {
      (/Action.binding).extract(from: $1)
    } then: { bindingAction in
      Reduce { state, _ in
        bindingAction.set(&state)
        return .none
      }
    }
    content
  }
  // or, with some `else` branch:
  //  public func body(content: Content) -> some ReducerProtocol<State, Action> {
  //    IfLet {
  //      (/Action.binding).extract(from: $1)
  //    } then: { bindingAction in
  //      Reduce { state, _ in
  //        bindingAction.set(&state)
  //        return .none
  //      }
  //      content
  //    } else: {
  //      content
  //    }
  //  }
}
#endif

