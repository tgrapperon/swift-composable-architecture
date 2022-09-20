import Combine
import SwiftUI

// TODO: Handle custom deduplication

final class ObservedViewStore<StoreState, StoreAction, ViewState, ViewAction>: ViewStore<
  StoreState, StoreAction
>
{
  private let dynamicDeduplicator: DynamicDeduplicator<StoreState>
  let store: Store<StoreState, StoreAction>
  private var token: UInt = 0
  let toViewState: (StoreState) -> ViewState
  let fromViewAction: (ViewAction) -> StoreAction
  var viewStateCancellable: AnyCancellable?
  var viewState: ViewState

  init(
    store: Store<StoreState, StoreAction>,
    observe toViewState: @escaping (StoreState) -> ViewState,
    send fromViewAction: @escaping (ViewAction) -> StoreAction,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool
  ) {

    let dynamicDeduplicator: DynamicDeduplicator<StoreState> = .init { lhs, rhs in
      isDuplicate(toViewState(lhs), toViewState(rhs))
    }
    self.dynamicDeduplicator = dynamicDeduplicator
    self.store = store
    self.viewState = toViewState(store.state.value)
    self.toViewState = toViewState
    self.fromViewAction = fromViewAction
    super.init(store, removeDuplicates: dynamicDeduplicator.isDuplicate(lhs:rhs:))
    self.viewStateCancellable = store.state
      .dropFirst()
      .map(toViewState)
      .sink { [weak self] viewState in self?.viewState = viewState }
  }

  var observedStore: ObservedStore<StoreState, StoreAction, ViewState, ViewAction> {
    defer { token += 1 }
    return ObservedStore(
      state: self.state,
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
  func register<ID: Hashable>(comparison: @escaping (State, State) -> Bool, id: ID) {
    self.dynamicComparisons[id] = comparison
  }
  func disposeComparison<ID: Hashable>(id: ID) {
    self.dynamicComparisons[id] = nil
  }
}

@available(iOS 14, tvOS 14, macOS 11, watchOS 7, *)
public struct WithObservedStore<StoreState, StoreAction, ViewState, ViewAction, Content: View>: View
{
  let content: (ObservedStore<StoreState, StoreAction, ViewState, ViewAction>) -> Content
  @StateObject var viewStore: ObservedViewStore<StoreState, StoreAction, ViewState, ViewAction>

  public init(
    _ store: Store<StoreState, StoreAction>,
    observe: @escaping (StoreState) -> ViewState,
    send: @escaping (ViewAction) -> StoreAction,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, ViewState, ViewAction>)
      -> Content
  ) where ViewState: Equatable {
    self._viewStore = .init(
      wrappedValue: .init(
        store: store,
        observe: observe,
        send: send,
        removeDuplicates: ==
      ))
    self.content = content
  }

  public init(
    _ store: Store<StoreState, StoreAction>,
    observe: @escaping (StoreState) -> ViewState,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, ViewState, ViewAction>)
      -> Content
  ) where ViewState: Equatable, ViewAction == StoreAction {
    self._viewStore = .init(
      wrappedValue: .init(
        store: store,
        observe: observe,
        send: { $0 },
        removeDuplicates: ==
      ))
    self.content = content
  }

  public init(
    _ store: Store<StoreState, StoreAction>,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, ViewState, ViewAction>)
      -> Content
  )
  where
    ViewState == Void,
    ViewAction == StoreAction
  {
    self._viewStore = .init(
      wrappedValue: .init(
        store: store,
        observe: { _ in () },
        send: { $0 },
        removeDuplicates: ==
      ))
    self.content = content
  }

  public var body: some View {
    content(viewStore.observedStore)
  }
}

@dynamicMemberLookup
public struct ObservedStore<StoreState, StoreAction, ViewState, ViewAction> {
  let state: StoreState
  let token: UInt
  let viewStore: ObservedViewStore<StoreState, StoreAction, ViewState, ViewAction>

  static func == (lhs: ObservedStore, rhs: ObservedStore) -> Bool {
    lhs.token == rhs.token
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<ViewState, Value>) -> Value {
    viewStore.viewState[keyPath: keyPath]
  }
}

extension ObservedStore {
  public func send(_ action: ViewAction) {
    self.viewStore.send(self.viewStore.fromViewAction(action))
  }
}

extension ObservedStore {
  @_disfavoredOverload
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (StoreState) -> ChildState,
    action fromChildAction: @escaping (ChildAction) -> StoreAction
  ) -> Store<ChildState, ChildAction> {
    self.viewStore.store.scope(state: toChildState, action: fromChildAction)
  }

  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (StoreState) -> ChildState?,
    action fromChildAction: @escaping (ChildAction) -> StoreAction
  ) -> Store<ChildState, ChildAction>? {
    guard let optionalChildState = toChildState(self.state)
    else { return nil }
    return self.viewStore.store.scope(
      state: {
        toChildState($0) ?? optionalChildState
      }, action: fromChildAction)
  }
}
