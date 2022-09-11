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
  public func forEach<StatesCollection: IdentifiedStatesCollection, Element: ReducerProtocol>(
    _ toElementsState: WritableKeyPath<State, StatesCollection>,
    action toElementAction: CasePath<Action, (StatesCollection.ID, Element.Action)>,
    @ReducerBuilderOf<Element> _ element: () -> Element,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, ForEachAtKeyPath<State, StatesCollection>, Element> {
    _ForEachReducer<Self, ForEachAtKeyPath<State, StatesCollection>, Element>(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: element(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
  
  @inlinable
  public func forEach<StatesCollection: IdentifiedStatesCollection, Element: ReducerProtocol>(
    update: ForEachModifiedAtKeyPath<State, StatesCollection>,
    action toElementAction: CasePath<Action, (StatesCollection.ID, Element.Action)>,
    @ReducerBuilderOf<Element> _ element: () -> Element,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, ForEachModifiedAtKeyPath<State, StatesCollection>, Element> {
    _ForEachReducer<Self, ForEachModifiedAtKeyPath<State, StatesCollection>, Element>(
      parent: self,
      toElementsState: update,
      toElementAction: toElementAction,
      element: element(),
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public protocol ForEachConversion {
  associatedtype Parent
  associatedtype StatesCollection: IdentifiedStatesCollection
  
  typealias ID = StatesCollection.ID
  typealias Element = StatesCollection.State
  func canExtract(parent: Parent, id: ID) -> Bool
  func extract(parent: Parent, id: ID) -> Element?
  func embed(parent: inout Parent, id: ID, element: Element?)
  
  func modify<T>(parent: inout Parent, id: ID, block: (inout Element) -> T) -> T
}

extension ForEachConversion {
  public func canExtract(parent: Parent, id: ID) -> Bool {
    extract(parent: parent, id: id) != nil
  }
  
  public func modify<T>(parent: inout Parent, id: ID, block: (inout Element) -> T) -> T {
    var element = extract(parent: parent, id: id)!
    defer {
      embed(parent: &parent, id: id, element: element)
    }
    return block(&element)
  }
}

public struct ForEachAtKeyPath<ParentState, Collection: IdentifiedStatesCollection>: ForEachConversion {
  public typealias Parent = ParentState
  public typealias StatesCollection = Collection
  let keyPath: WritableKeyPath<ParentState, Collection>
  
  public init(_ keyPath: WritableKeyPath<ParentState, Collection>) {
    self.keyPath = keyPath
  }
  
  public func extract(parent: ParentState, id: ID) -> Element? {
    parent[keyPath: keyPath][stateID: id]
  }
  
  public func embed(parent: inout ParentState, id: ID, element: Element?) {
    parent[keyPath: keyPath][stateID: id] = element
  }
  
  public func modify<T>(parent: inout ParentState, id: ID, block: (inout Element) -> T) -> T {
    block(&parent[keyPath: keyPath][stateID: id]!)
  }
}

public struct ForEachModifiedAtKeyPath<ParentState, Collection: IdentifiedStatesCollection>: ForEachConversion {
  public typealias Parent = ParentState
  public typealias StatesCollection = Collection
  
  let keyPath: WritableKeyPath<ParentState, Collection>
  let updateElement: (Parent, ID, inout Element) -> Void

  public init(
    _ keyPath: WritableKeyPath<ParentState, Collection>,
    updateElement: @escaping (Parent, ID, inout Element) -> Void
  ) {
    self.keyPath = keyPath
    self.updateElement = updateElement
  }
  
  public func canExtract(parent: ParentState, id: ID) -> Bool {
    parent[keyPath: keyPath][stateID: id] != nil
  }
  
  public func extract(parent: ParentState, id: ID) -> Element? {
    guard var element = parent[keyPath: keyPath][stateID: id]
    else { return nil }
    updateElement(parent, id, &element)
    return element
  }
  
  public func embed(parent: inout ParentState, id: ID, element: Element?) {
    parent[keyPath: keyPath][stateID: id] = element
  }
}

public struct _ForEachReducer<
  Parent: ReducerProtocol,
  ElementConversion: ForEachConversion,
  Element: ReducerProtocol
>: ReducerProtocol
where ElementConversion.StatesCollection.State == Element.State, ElementConversion.Parent == Parent.State {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: ElementConversion

  @usableFromInline
  let toElementAction: CasePath<Parent.Action, (ElementConversion.StatesCollection.ID, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init<States: IdentifiedStatesCollection>(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, States>,
    toElementAction: CasePath<Parent.Action, (States.ID, Element.Action)>,
    element: Element,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) where ElementConversion == ForEachAtKeyPath<Parent.State, States> {
    self.parent = parent
    self.toElementsState = ForEachAtKeyPath(toElementsState)
    self.toElementAction = toElementAction
    self.element = element
    self.file = file
    self.fileID = fileID
    self.line = line
  }
  
  @inlinable
  init<States: IdentifiedStatesCollection>(
    parent: Parent,
    toElementsState: ElementConversion,
    toElementAction: CasePath<Parent.Action, (States.ID, Element.Action)>,
    element: Element,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) where ElementConversion == ForEachModifiedAtKeyPath<Parent.State, States> {
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
    if !self.toElementsState.canExtract(parent: state, id: id) {
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
    
    return self.toElementsState
      .modify(parent: &state, id: id, block: { self.element.reduce(into: &$0, action: elementAction)})
      .map { self.toElementAction.embed((id, $0)) }
  }
}
