import SwiftUI
import Combine
@dynamicMemberLookup
public class ScopedViewStore<StoreState, StoreAction, State, Action> {
  // N.B. `ViewStore` does not use a `@Published` property, so `objectWillChange`
  // won't be synthesized automatically. To work around issues on iOS 13 we explicitly declare it.
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()
  
  let _send: (Action) -> Task<Void, Never>?
  let _state: CurrentValueRelay<State>
  let toViewState: (StoreState) -> State
  let fromViewAction: (Action) -> StoreAction
  private var viewCancellable: AnyCancellable?

  
  /// Initializes a view store from a store.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed.
  public init(
    _ store: Store<StoreState, StoreAction>,
    observe toViewState: @escaping (StoreState) -> State,
    send fromViewAction: @escaping (Action) -> StoreAction,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self._send = { store.send(fromViewAction($0)) }
    self._state = CurrentValueRelay(toViewState(store.state.value))
    self.toViewState = toViewState
    self.fromViewAction = fromViewAction
    self.viewCancellable = store.state
      .map(toViewState)
      .removeDuplicates(by: isDuplicate)
      .sink { [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
        guard let objectWillChange = objectWillChange, let _state = _state else { return }
        objectWillChange.send()
        _state.value = $0
      }
  }
  
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) where State == StoreState, Action == StoreAction {
    self._send = { store.send($0) }
    self._state = CurrentValueRelay(store.state.value)
    self.toViewState = { $0 }
    self.fromViewAction = { $0 }
    self.viewCancellable = store.state
      .removeDuplicates(by: isDuplicate)
      .sink { [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
        guard let objectWillChange = objectWillChange, let _state = _state else { return }
        objectWillChange.send()
        _state.value = $0
      }
  }
  
  internal init(_ viewStore: ScopedViewStore) {
    self._send = viewStore._send
    self._state = viewStore._state
    self.toViewState = viewStore.toViewState
    self.fromViewAction = viewStore.fromViewAction
    self.viewCancellable = viewStore.viewCancellable
    self.objectWillChange = viewStore.objectWillChange
  }
}


extension ScopedViewStore: ObservableObject {}
