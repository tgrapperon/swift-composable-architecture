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

public protocol WritableDomainScope: DomainScope {
  func fromChildState(_ parentState: inout ParentState, _ childState: Child.State)
  func toChildAction(_ parentAction: ParentAction) -> Child.Action?
  func modify<T>(_ parent: inout ParentState, body: (inout Child.State) -> T) throws -> T
}

extension WritableDomainScope {
  public func modify<T>(_ parent: inout ParentState, body: (inout Child.State) -> T) throws -> T {
    var child = try toChildState(parent)
    defer { fromChildState(&parent, child) }
    return body(&child)
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
    case casePath(
      CasePath<ParentState, Child.State>,
      file: StaticString,
      fileID: StaticString,
      line: UInt
    )
    case keyPath(WritableKeyPath<ParentState, Child.State>)
  }
  public let statePath: StatePath
  public let actionCasePath: CasePath<ParentAction, Child.Action>
  
  public init(
    state keyPath: WritableKeyPath<ParentState, Child.State>,
    action: CasePath<ParentAction, Child.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.statePath = .keyPath(keyPath)
    self.actionCasePath = action
  }
  
  public func toChildState(_ parentState: ParentState) throws -> (Child.State) {
    switch statePath {
    case let .keyPath(keyPath):
      return parentState[keyPath: keyPath]
    case let .casePath(casePath, file: file, fileID: fileID, line: line):
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
    switch self.statePath {
    case let .keyPath(keyPath):
      parentState[keyPath: keyPath] = childState
    case let .casePath(casePath, file: _, fileID: _, line: _):
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
    case let .casePath(casePath, file: _, fileID: _, line: _):
      return try casePath.modify(&parent, body)
    }
  }
}

extension WritableDirectDomainScope {
  public init(
    state casePath: CasePath<ParentState, Child.State>,
    action: CasePath<ParentAction, Child.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.statePath = .casePath(casePath, file: file, fileID: fileID, line: line)
    self.actionCasePath = action
  }
}
