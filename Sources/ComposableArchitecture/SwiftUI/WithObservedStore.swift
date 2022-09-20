import SwiftUI

final class ObservedViewStore<StoreState, StoreAction, ViewState: Equatable, ViewAction>: ViewStore<
  StoreState, StoreAction
>
{
  private let dynamicDeduplicator: DynamicDeduplicator<StoreState>
  private var token: UInt = 0
  
  init(
    store: Store<StoreState, StoreAction>,
    observe toViewState : @escaping (StoreState) -> ViewState,
    send: @escaping (ViewAction) -> StoreAction
  ) {

    let dynamicDeduplicator: DynamicDeduplicator<StoreState> = .init { lhs, rhs in
      toViewState(lhs) == toViewState(rhs)
    }
    self.dynamicDeduplicator = dynamicDeduplicator
    super.init(store, removeDuplicates: dynamicDeduplicator.isDuplicate(lhs:rhs:))
  }
  
  var observedStore: ObservedStore<StoreState, StoreAction, ViewState, ViewAction> {
    defer { token += 1 }
    return ObservedStore(
      token: self.token,
      viewStore: self
    )
  }
}

final class DynamicDeduplicator<State> {
  private let baseline: (State, State) -> Bool
  private var dynamicComparisons: [AnyHashable: (State, State) -> Bool] = [:]
  init(baseline: @escaping (State, State) -> Bool) {
    self.baseline = baseline
  }
  func isDuplicate(lhs: State, rhs: State) -> Bool {
    if !baseline(lhs, rhs) { return false }
    if dynamicComparisons.isEmpty { return true }
    return !dynamicComparisons.values.contains { !$0(lhs, rhs) }
  }
}

@available(iOS 14, tvOS 14, macOS 11, watchOS 7, *)
public struct WithObservedStore<StoreState, StoreAction, ViewState: Equatable, ViewAction, Content: View>: View
{
  let content: (ObservedStore<StoreState, StoreAction, ViewState, ViewAction>) -> Content
  @StateObject var viewStore: ObservedViewStore<StoreState, StoreAction, ViewState, ViewAction>

  init(
    store: Store<StoreState, StoreAction>,
    observe: @escaping (StoreState) -> ViewState,
    send: @escaping (ViewAction) -> StoreAction,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, ViewState, ViewAction>)
      -> Content
  ) {
    self._viewStore = .init(wrappedValue: .init(store: store, observe: observe, send: send))
    self.content = content
  }

  public var body: some View {
    content(viewStore.observedStore)
  }
}

struct ObservedStore<StoreState, StoreAction, ViewState, ViewAction> {
  let token: UInt
  let viewStore: ViewStore<StoreState, StoreAction>
}
