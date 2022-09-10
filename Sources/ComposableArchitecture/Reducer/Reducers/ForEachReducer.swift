import OrderedCollections

public protocol ForEachStateProvider {
  associatedtype IDs: Collection
  associatedtype States: Collection
  
  typealias ID = IDs.Element
  typealias State = States.Element
  
  func stateIdentifiers() -> IDs
  func state(id: IDs.Element) -> State?
  func states() -> States
  mutating func yield<T>(id: IDs.Element, modify: (inout State) -> T) -> T
}

extension IdentifiedArray: ForEachStateProvider {
  public func stateIdentifiers() -> OrderedSet<ID> {
    self.ids
  }

  public func state(id: ID) -> Element? {
    self[id: id]
  }

  public mutating func yield<T>(id: ID, modify: (inout Element) -> T) -> T {
    modify(&self[id: id]!)
  }
  public func states() -> Self {
    self
  }
}

extension OrderedDictionary: ForEachStateProvider {
  typealias Element = Value
  public func stateIdentifiers() -> OrderedSet<Key> {
    self.keys
  }

  public func state(id: Key) -> Value? {
    self[id]
  }

  public mutating func yield<T>(id: Key, modify: (inout Value) -> T) -> T {
    modify(&self[id]!)
  }
  
  public func states() -> OrderedDictionary<Key, Value>.Values {
    self.values
  }
}

extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on elements of a collection in parent
  /// state.
  ///
  /// - Parameters:
  ///   - toElementsState: A writable key path from parent state to an `IdentifiedArray` of child
  ///     state.
  ///   - toElementAction: A case path from parent action to child identifier and child actions.
  ///   - element: A reducer that will be invoked with child actions against elements of child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  public func forEach<StateProvider: ForEachStateProvider, Element: ReducerProtocol>(
    _ toElementsState: WritableKeyPath<State, StateProvider>,
    action toElementAction: CasePath<Action, (StateProvider.ID, Element.Action)>,
    @ReducerBuilderOf<Element> _ element: () -> Element,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, StateProvider, Element> {
    _ForEachReducer<Self, StateProvider, Element>(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: element(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _ForEachReducer<
  Parent: ReducerProtocol,
  StateProvider: ForEachStateProvider,
  Element: ReducerProtocol
>: ReducerProtocol
where StateProvider.State == Element.State {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: WritableKeyPath<Parent.State, StateProvider>

  @usableFromInline
  let toElementAction: CasePath<Parent.Action, (StateProvider.ID, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, StateProvider>,
    toElementAction: CasePath<Parent.Action, (StateProvider.ID, Element.Action)>,
    element: Element,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    self.reduceForEach(into: &state, action: action)
      .merge(with: self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceForEach(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    if state[keyPath: self.toElementsState].state(id: id) == nil {
      runtimeWarning(
        """
        A "forEach" at "%@:%d" received an action for a missing element.

          Action:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer removed an element with this ID before this reducer ran. This reducer \
        must run before any other reducer removes an element, which ensures that element reducers \
        can handle their actions while their state is still available.

        • An in-flight effect emitted this action when state contained no element at this ID. \
        While it may be perfectly reasonable to ignore this action, consider canceling the \
        associated effect before an element is removed, especially if it is a long-living effect.

        • This action was sent to the store while its state contained no element at this ID. To \
        fix this make sure that actions for this reducer can only be sent from a view store when \
        its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
        """,
        [
          "\(self.fileID)",
          line,
          debugCaseOutput(action),
        ],
        file: self.file,
        line: self.line
      )
      return .none
    }
    return state[keyPath: self.toElementsState]
      .yield(id: id, modify: { self.element.reduce(into: &$0, action: elementAction)})
      .map { self.toElementAction.embed((id, $0)) }
  }
}
