import Combine
import OrderedCollections
import SwiftUI

@dynamicMemberLookup
public class ScopedViewStore<StoreState, StoreAction, State, Action> {
  // N.B. `ViewStore` does not use a `@Published` property, so `objectWillChange`
  // won't be synthesized automatically. To work around issues on iOS 13 we explicitly declare it.
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()

  let _send: (Action) -> Task<Void, Never>?
  let _state: CurrentValueRelay<State>
  // Not used for now
  //  let toViewState: (StoreState) -> State
  //  let fromViewAction: (Action) -> StoreAction
  internal var viewCancellable: AnyCancellable?

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
    //    self.toViewState = toViewState
    //    self.fromViewAction = fromViewAction
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
    //    self.toViewState = { $0 }
    //    self.fromViewAction = { $0 }
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
    //    self.toViewState = viewStore.toViewState
    //    self.fromViewAction = viewStore.fromViewAction
    self.viewCancellable = viewStore.viewCancellable
    self.objectWillChange = viewStore.objectWillChange
  }

  internal init(
    _send: @escaping (Action) -> Task<Void, Never>?,
    _state: CurrentValueRelay<State>,
    viewCancellable: AnyCancellable?
  ) {
    self._send = _send
    self._state = _state
    self.viewCancellable = viewCancellable
  }
  internal init(
    _send: @escaping (Action) -> Task<Void, Never>?,
    _state: CurrentValueRelay<State>,
    viewCancellable: AnyCancellable?,
    objectWillChange: ObservableObjectPublisher
  ) {
    self._send = _send
    self._state = _state
    self.viewCancellable = viewCancellable
    self.objectWillChange = objectWillChange
  }
}

extension ScopedViewStore: ObservableObject {}

public protocol ViewStateProtocol: Equatable {
  associatedtype StoreState
}

//@propertyWrapper
public struct StoreValue<ID: Hashable, State, Action>: Identifiable, Hashable {
  public let id: ID
  final class Storage {
    lazy var store: Store<State, Action> = initialValue()
    var initialValue: (() -> Store<State, Action>)!
  }
  let storage = Storage()
  init(id: ID, store: @autoclosure @escaping () -> Store<State, Action>) {
    self.id = id
    self.storage.initialValue = store
  }
  public var wrappedValue: Store<State, Action> {
    storage.store
  }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }
}

@MainActor
public class ObservedStore<StoreState, StoreAction, State, Action>: ScopedViewStore<
  StoreState, StoreAction, State, Action
>
{
  let store: Store<StoreState, StoreAction>
  var scopes: [AnyHashable: Any] = [:]
  var accessoryIsDuplicateChecks: [AnyHashable: (StoreState, StoreState) -> Bool] = [:]

  func isAssessoryDuplicate(_ lhs: StoreState, _ rhs: StoreState) -> Bool {
    !self.accessoryIsDuplicateChecks.values.contains { $0(lhs, rhs) == false }
  }

  public init(
    store: Store<StoreState, StoreAction>, observe toViewState: @escaping (StoreState) -> State,
    send fromViewAction: @escaping (Action) -> StoreAction,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self.store = store

    //    self.toViewState = toViewState
    //    self.fromViewAction = fromViewAction
    super.init(
      _send: { store.send(fromViewAction($0)) },
      _state: CurrentValueRelay(toViewState(store.state.value)),
      viewCancellable: nil
    )

    let accessoryChanges = store.state
      .removeDuplicates { [weak self] in self?.isAssessoryDuplicate($0, $1) ?? true }
      .map(toViewState)
    let viewStateChanges = store.state
      .map(toViewState)
      .removeDuplicates(by: isDuplicate)

    self.viewCancellable = accessoryChanges.merge(with: viewStateChanges).sink {
      [weak objectWillChange = self.objectWillChange, weak _state = self._state] in
      guard let objectWillChange = objectWillChange, let _state = _state else { return }
      objectWillChange.send()
      _state.value = $0
    }
  }

  init(_ viewStore: ObservedStore) {
    self.store = viewStore.store
    self.accessoryIsDuplicateChecks = viewStore.accessoryIsDuplicateChecks
    self.scopes = viewStore.scopes
    super.init(
      _send: viewStore._send,
      _state: viewStore._state,
      viewCancellable: viewStore.viewCancellable,
      objectWillChange: viewStore.objectWillChange
    )
  }

  func observeAccessoryState(
    id: AnyHashable, isDuplicate: @escaping (StoreState, StoreState) -> Bool
  ) {
    self.accessoryIsDuplicateChecks[id] = isDuplicate
  }
  func unobserveAccessoryState(id: AnyHashable) {
    self.accessoryIsDuplicateChecks[id] = nil
  }
}

extension ObservedStore {
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (StoreState) -> ChildState,
    action fromChildAction: @escaping (ChildAction) -> StoreAction,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> Store<ChildState, ChildAction> {
    let id = "\(file)\(line)\(column)"
    if let scoped = scopes[id] as? Store<ChildState, ChildAction> {
      return scoped
    }
    let scoped = store.scope(state: toChildState, action: fromChildAction)
    self.scopes[id] = scoped
    return scoped
  }

  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (StoreState) -> ChildState?,
    action fromChildAction: @escaping (ChildAction) -> StoreAction,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> Store<ChildState, ChildAction>? {
    let id = "\(file)\(line)\(column)"

    self.observeAccessoryState(id: id) {
      (toChildState($0) == nil) == (toChildState($1) == nil)
    }

    guard toChildState(store.state.value) != nil else {
      self.scopes[id] = nil
      self.unobserveAccessoryState(id: id)
      return nil
    }
    if let scoped = scopes[id] as? Store<ChildState, ChildAction> {
      return scoped
    }
    var lastNonNilChildState: ChildState?
    let scoped = store.scope(
      state: {
        if let childState = toChildState($0) {
          lastNonNilChildState = childState
          return childState
        }
        return lastNonNilChildState!
      }, action: fromChildAction)
    self.scopes[id] = scoped
    return scoped
  }

  public func scope<EachState, EachAction, ID: Hashable>(
    state toEachState: @escaping (StoreState) -> IdentifiedArray<ID, EachState>,
    action fromEachAction: @escaping (ID, EachAction) -> StoreAction,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> IdentifiedArrayOf<StoreValue<ID, EachState, EachAction>> {
    let prefix = "\(file)\(line)\(column)"

    self.observeAccessoryState(id: prefix) {
      // TODO: restore memcmp
      toEachState($0).ids == toEachState($1).ids
    }

    let ids = toEachState(self.store.state.value).ids

    let makeStore: (ID) -> (() -> Store<EachState, EachAction>)? = {
      [weak store = self.store, weak self] localID -> (() -> Store<EachState, EachAction>)? in
      guard let store = store else { return nil }
      let id: [AnyHashable] = [prefix, localID]
      guard toEachState(store.state.value)[id: localID] != nil
      else {
        self?.scopes[id] = nil
        self?.unobserveAccessoryState(id: id)
        return nil
      }
      if let scoped = self?.scopes[id] as? Store<EachState, EachAction> {
        return { scoped }
      }
      var lastNonNilEachState: EachState?
      let scoped: Store<EachState, EachAction> = store.scope(
        state: {
          if let eachState = toEachState($0)[id: localID] {
            lastNonNilEachState = eachState
            return eachState
          }
          return lastNonNilEachState!
        }, action: { fromEachAction(localID, $0) })

      self?.scopes[id] = scoped
      return { scoped }
    }
    return IdentifiedArrayOf<StoreValue<ID, EachState, EachAction>>(
      uncheckedUniqueElements: ids.compactMap { id in
        guard let makeStore = makeStore(id) else { return nil }
        return StoreValue<ID, EachState, EachAction>(id: id, store: makeStore())
      }
    )
  }
}

@propertyWrapper
public struct LastNonNil<Value> {
  public init(wrappedValue: Value?) {
    self._wrappedValue = wrappedValue
  }
  public var _wrappedValue: Value?

  public var wrappedValue: Value? {
    get { _wrappedValue }
    set {
      guard let newValue = newValue else { return }
      _wrappedValue = newValue
    }
  }
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
public struct WithObservedStore<StoreState, StoreAction, State, Action, Content: View>: View {
  @StateObject var observedStore: ObservedStore<StoreState, StoreAction, State, Action>
  let content: (ObservedStore<StoreState, StoreAction, State, Action>) -> Content

  public var body: some View {
    content(observedStore)
  }
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
extension WithObservedStore {
  public init(
    _ store: Store<StoreState, StoreAction>,
    observe toViewState: @escaping (StoreState) -> State,
    send fromViewAction: @escaping (Action) -> StoreAction,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, State, Action>) ->
      Content
  ) {
    self._observedStore = .init(
      wrappedValue:
        ObservedStore(
          store: store,
          observe: toViewState,
          send: fromViewAction,
          removeDuplicates: isDuplicate
        )
    )
    self.content = content
  }

  public init(
    _ store: Store<StoreState, StoreAction>,
    observe toViewState: @escaping (StoreState) -> State,
    send fromViewAction: @escaping (Action) -> StoreAction,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, State, Action>) ->
      Content
  ) where State: Equatable {
    self._observedStore = .init(
      wrappedValue:
        ObservedStore(
          store: store,
          observe: toViewState,
          send: fromViewAction,
          removeDuplicates: ==
        )
    )
    self.content = content
  }

  public init(
    _ store: Store<StoreState, StoreAction>,
    observe toViewState: @escaping (StoreState) -> State,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, State, Action>) ->
      Content
  ) where Action == StoreAction {
    self._observedStore = .init(
      wrappedValue:
        ObservedStore(
          store: store,
          observe: toViewState,
          send: { $0 },
          removeDuplicates: isDuplicate
        )
    )
    self.content = content
  }

  public init(
    _ store: Store<StoreState, StoreAction>,
    observe toViewState: @escaping (StoreState) -> State,
    @ViewBuilder content: @escaping (ObservedStore<StoreState, StoreAction, State, Action>) ->
      Content
  ) where State: Equatable, Action == StoreAction {
    self._observedStore = .init(
      wrappedValue:
        ObservedStore(
          store: store,
          observe: toViewState,
          send: { $0 },
          removeDuplicates: ==
        )
    )
    self.content = content
  }
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
extension WithObservedStore: DynamicViewContent where Content: DynamicViewContent {
  public var data: Content.Data { self.content(observedStore).data }
}
