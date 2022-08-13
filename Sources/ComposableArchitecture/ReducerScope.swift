
public protocol OptionalStateScope {
  associatedtype Parent: ReducerProtocol
  associatedtype Child: ReducerProtocol
  func extractState(from parentState: Parent.State) -> Child.State?
  func embedState(_ childState: Child.State, into parentState: inout Parent.State)
}

public protocol StateScope: OptionalStateScope {
  func extractState(from parentState: Parent.State) -> Child.State
}
extension StateScope {
  public func extractState(from parentState: Parent.State) -> Child.State? {
    self.extractState(from:parentState)
  }
}

public protocol ActionScope {
  associatedtype Parent: ReducerProtocol
  associatedtype Child: ReducerProtocol
  func extractAction(from parentAction: Parent.Action) -> Child.Action?
  func embedAction (_ childAction: Child.Action) -> Parent.Action
}

public protocol ReducerScope {
  associatedtype Parent: ReducerProtocol
  associatedtype Child: ReducerProtocol
  associatedtype State: StateScope where State.Parent == Parent, State.Child == Child
  associatedtype Action: ActionScope where Action.Parent == Parent, Action.Child == Child

  var state: State { get }
  var action: Action { get }
}

extension ReducerScope {
  @inlinable
  func extractState(from parentState: Parent.State) -> Child.State {
    state.extractState(from:parentState)
  }
  @inlinable
  func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
    state.embedState(childState, into: &parentState)
  }
  @inlinable
  func extractAction(from parentAction: Parent.Action) -> Child.Action? {
    action.extractAction(from:parentAction)
  }
  @inlinable
  func embedAction (_ childAction: Child.Action) -> Parent.Action {
    action.embedAction(childAction)
  }
}

public struct IdentityStateScope<Parent: ReducerProtocol, Child: ReducerProtocol>: StateScope where Parent.State == Child.State {
  
  @inlinable
  public func extractState(from parentState: Parent.State) -> Child.State {
    parentState
  }
  @inlinable
  public func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
    parentState = childState
  }
}

public struct WritableKeyPathStateScope<Parent: ReducerProtocol, Child: ReducerProtocol>: StateScope {
  @usableFromInline
  let keyPath: WritableKeyPath<Parent.State, Child.State>
  
  @inlinable
  public init(_ keyPath: WritableKeyPath<Parent.State, Child.State>) {
    self.keyPath = keyPath
  }
  
  @inlinable
  public func extractState(from parentState: Parent.State) -> Child.State {
    parentState[keyPath: keyPath]
  }
  @inlinable
  public func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
    parentState[keyPath: keyPath] = childState
  }
}

public struct KeyPathStateScope<Parent: ReducerProtocol, Child: ReducerProtocol>: StateScope {
  @usableFromInline
  let keyPath: WritableKeyPath<Parent.State, Child.State>
  
  @inlinable
  public init(_ keyPath: WritableKeyPath<Parent.State, Child.State>) {
    self.keyPath = keyPath
  }
  
  @inlinable
  public func extractState(from parentState: Parent.State) -> Child.State {
    parentState[keyPath: keyPath]
  }
  @inlinable
  public func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
  }
}

extension KeyPathStateScope: ReducerScope where Parent.Action == Child.Action {
  public var state: Self { self }
  public var action: IdentityActionScope<Parent, Child> { .init() }
}

public struct CasePathStateScope<Parent: ReducerProtocol, Child: ReducerProtocol>: OptionalStateScope {
  @usableFromInline
  let casePath: CasePath<Parent.State, Child.State>
  
  @inlinable
  init(_ casePath: CasePath<Parent.State, Child.State>) {
    self.casePath = casePath
  }
  @inlinable
  public func extractState(from parentState: Parent.State) -> Child.State? {
    casePath.extract(from:parentState)
  }
  @inlinable
  public func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
    parentState = casePath.embed(childState)
  }
}

public struct BlockStateScope<Parent: ReducerProtocol, Child: ReducerProtocol>: StateScope {
  @usableFromInline
  let extractFromParent: (Parent.State) -> Child.State
  @usableFromInline
  let embedIntoParent: (Child.State, inout Parent.State) -> Void

  public init(
    extractFromParent: @escaping (Parent.State) -> Child.State,
    embedIntoParent: @escaping (Child.State, inout Parent.State) -> Void = {_, _ in ()}) {
    self.extractFromParent = extractFromParent
    self.embedIntoParent = embedIntoParent
  }
  
  @inlinable
  public func extractState(from parentState: Parent.State) -> Child.State {
    extractFromParent(parentState)
  }
  
  @inlinable
  public func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
    embedIntoParent(childState,&parentState)
  }
}

public struct OptionalBlockStateScope<Parent: ReducerProtocol, Child: ReducerProtocol>: OptionalStateScope {
  @usableFromInline
  let extractFromParent: (Parent.State) -> Child.State?
  @usableFromInline
  let embedIntoParent: (Child.State, inout Parent.State) -> Void

  public init(
    extractFromParent: @escaping (Parent.State) -> Child.State?,
    embedIntoParent: @escaping (Child.State, inout Parent.State) -> Void = {_, _ in ()}) {
    self.extractFromParent = extractFromParent
    self.embedIntoParent = embedIntoParent
  }
  
  @inlinable
  public func extractState(from parentState: Parent.State) -> Child.State? {
    extractFromParent(parentState)
  }
  
  @inlinable
  public func embedState(_ childState: Child.State, into parentState: inout Parent.State) {
    embedIntoParent(childState,&parentState)
  }
}

public struct IdentityActionScope<Parent: ReducerProtocol, Child: ReducerProtocol>: ActionScope where Parent.Action == Child.Action {
  
  @inlinable
  public func extractAction(from parentAction: Parent.Action) -> Child.Action? {
    parentAction
  }
  @inlinable
  public func embedAction(_ childAction: Child.Action) -> Parent.Action {
    childAction
  }
}

public struct CasePathActionScope<Parent: ReducerProtocol, Child: ReducerProtocol>: ActionScope {
  @usableFromInline
  let casePath: CasePath<Parent.Action, Child.Action>
  
  @inlinable
  init(_ casePath: CasePath<Parent.Action, Child.Action>) {
    self.casePath = casePath
  }
  @inlinable
  public func extractAction(from parentAction: Parent.Action) -> Child.Action? {
    casePath.extract(from:parentAction)
  }
  @inlinable
  public func embedAction(_ childAction: Child.Action) -> Parent.Action {
    casePath.embed(childAction)
  }
}


extension CasePathActionScope: ReducerScope where Parent.State == Child.State {
  public var state: IdentityStateScope<Parent, Child> { .init() }
  public var action: Self { self }
}

public struct BlockActionScope<Parent: ReducerProtocol, Child: ReducerProtocol>: ActionScope {
  @usableFromInline
  let extractFromParent: (Parent.Action) -> Child.Action?
  @usableFromInline
  let embedIntoParent: (Child.Action) -> Parent.Action
  @inlinable
  public func extractAction(from parentAction: Parent.Action) -> Child.Action? {
    extractFromParent(parentAction)
  }
  @inlinable
  public func embedAction(_ childAction: Child.Action) -> Parent.Action {
    embedIntoParent(childAction)
  }
}


