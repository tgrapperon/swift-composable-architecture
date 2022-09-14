#if swift(>=5.7)
public protocol Domain<State, Action> {
  associatedtype State
  associatedtype Action
}
#else
public protocol Domain {
  associatedtype State
  associatedtype Action
}
#endif

public protocol DomainScope {
  associatedtype ParentState
  associatedtype ParentAction
  associatedtype Child: Domain
  func toChildState(_ parentState: ParentState) throws -> (Child.State)
  func fromChildAction(_ childAction: Child.Action) -> ParentAction
}

extension Optional: Domain where Wrapped: Domain {
  public typealias State = Wrapped.State?
  public typealias Action = Wrapped.Action
}

public protocol WritableDomainScope: DomainScope {
  func fromChildState(_ parentState: inout ParentState, _ childState: Child.State)
  func toChildAction(_ parentAction: ParentAction) -> Child.Action?
  func modify<T>(_ parent: inout ParentState, body: (inout Child.State) -> T) throws -> T
}

public extension WritableDomainScope {
  func modify<T>(_ parent: inout ParentState, body: (inout Child.State) -> T) throws -> T {
    var child = try toChildState(parent)
    defer { fromChildState(&parent, child) }
    return body(&child)
  }
}

public struct DerivedDomainScope<Scope: DomainScope>: DomainScope {
  public typealias Child = Scope.Child
  public typealias ParentState = Scope.ParentState
  public typealias ParentAction = Scope.ParentAction
  let domainScope: Scope
  @usableFromInline
  let update: @Sendable (ParentState, inout Child.State) -> Void
  @usableFromInline
  let embed: @Sendable (inout ParentState, Child.State) -> Void

  public func toChildState(_ parentState: Scope.ParentState) throws -> (Scope.Child.State) {
    var child = try domainScope.toChildState(parentState)
    update(parentState, &child)
    return child
  }

  public func fromChildAction(_ childAction: Scope.Child.Action) -> ParentAction {
    domainScope.fromChildAction(childAction)
  }
}

extension DerivedDomainScope: WritableDomainScope where Scope: WritableDomainScope {
  public func fromChildState(_ parentState: inout Scope.ParentState, _ childState: Scope.Child.State) {
    domainScope.fromChildState(&parentState, childState)
    embed(&parentState, childState)
  }

  public func toChildAction(_ parentAction: ParentAction) -> Scope.Child.Action? {
    domainScope.toChildAction(parentAction)
  }

  public func modify<T>(_ parent: inout Scope.ParentState, body: (inout Scope.Child.State) -> T) throws -> T {
    let (result, newChildState) = try domainScope.modify(&parent) { [parent] childState in
      self.update(parent, &childState)
      return (body(&childState), childState)
    }
    embed(&parent, newChildState)
    return result
  }
}

extension WritableDomainScope {
  @usableFromInline
  func derived(
    _ stateUpdate: DerivedDomainStateUpdate? = DerivedState.for(Child.State.self)
  ) -> DerivedDomainScope<Self> {
    if let stateUpdate = stateUpdate,
       let update = stateUpdate.update as? (Self.ParentState, inout Self.Child.State) -> Void,
       let embed = stateUpdate.embed as? (inout Self.ParentState, Self.Child.State) -> Void
    {
      return DerivedDomainScope(
        domainScope: self,
        update: { update($0, &$1) },
        embed: { embed(&$0, $1) }
      )
    } else {
      return DerivedDomainScope(
        domainScope: self,
        update: { _, _ in () },
        embed: { _, _ in () }
      )
    }
  }
}

@usableFromInline
struct DomainExtractionFailed: Error {
  @usableFromInline
  let file: StaticString
  @usableFromInline
  let fileID: StaticString
  @usableFromInline
  let line: UInt
}

public struct DirectDomainScope<ParentState, ParentAction, Child: Domain>: DomainScope {
  public let _toChildState: (ParentState) throws -> (Child.State)
  public let _fromChildAction: (Child.Action) -> (ParentAction)
  public init(
    state: @escaping (ParentState) throws -> (Child.State),
    action: @escaping (Child.Action) -> (ParentAction)
  ) {
    self._toChildState = state
    self._fromChildAction = action
  }

  public func toChildState(_ parentState: ParentState) throws -> (Child.State) {
    try _toChildState(parentState)
  }

  public func fromChildAction(_ childAction: Child.Action) -> ParentAction {
    _fromChildAction(childAction)
  }
}

// TODO: Find a shorter name
public struct WritableDirectDomainScope<ParentState, ParentAction, Child: Domain>: WritableDomainScope {
  public enum StatePath {
    case casePath(CasePath<ParentState, Child.State>)
    case keyPath(WritableKeyPath<ParentState, Child.State>)
  }

  public let statePath: StatePath
  public let actionCasePath: CasePath<ParentAction, Child.Action>

  @usableFromInline let file: StaticString
  @usableFromInline let fileID: StaticString
  @usableFromInline let line: UInt

  public init(
    state keyPath: WritableKeyPath<ParentState, Child.State>,
    action: CasePath<ParentAction, Child.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.statePath = .keyPath(keyPath)
    self.actionCasePath = action
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  public init<Wrapped>(
    state keyPath: WritableKeyPath<ParentState, Wrapped.State?>,
    action: CasePath<ParentAction, Wrapped.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Child == Wrapped? {
    self.statePath = .keyPath(keyPath)
    self.actionCasePath = action
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  public func toChildState(_ parentState: ParentState) throws -> (Child.State) {
    switch statePath {
    case let .keyPath(keyPath):
      return parentState[keyPath: keyPath]
    case let .casePath(casePath):
      guard let childState = casePath.extract(from: parentState) else {
        throw DomainExtractionFailed(file: file, fileID: fileID, line: line)
      }
      return childState
    }
  }

  public func fromChildAction(_ childAction: Child.Action) -> ParentAction {
    actionCasePath.embed(childAction)
  }

  public func fromChildState(_ parentState: inout ParentState, _ childState: Child.State) {
    switch statePath {
    case let .keyPath(keyPath):
      parentState[keyPath: keyPath] = childState
    case let .casePath(casePath):
      parentState = casePath.embed(childState)
    }
  }

  public func toChildAction(_ parentAction: ParentAction) -> Child.Action? {
    actionCasePath.extract(from: parentAction)
  }

  public func modify<T>(_ parent: inout ParentState, body: (inout Child.State) -> T) throws -> T {
    switch statePath {
    case let .keyPath(keyPath):
      return body(&parent[keyPath: keyPath])
    case let .casePath(casePath):
      return try casePath.modify(&parent, body)
    }
  }
}

public extension WritableDirectDomainScope {
  init(
    state casePath: CasePath<ParentState, Child.State>,
    action: CasePath<ParentAction, Child.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.statePath = .casePath(casePath)
    self.actionCasePath = action
    self.file = file
    self.fileID = fileID
    self.line = line
  }
}
