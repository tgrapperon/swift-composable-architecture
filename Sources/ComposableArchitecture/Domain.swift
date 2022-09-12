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
  // TODO: Convert to function requirements
  var toChildState: (ParentState) -> (Child.State)? { get }
//  var fromChildAction: (inout ParentAction, Child.Action) -> Void { get }
  var fromChildAction: (Child.Action) -> ParentAction { get }
}

public protocol WritableDomainScope: DomainScope {
  var fromChildState: (inout ParentState, Child.State) -> Void { get }
  var toChildAction: (ParentAction) -> Child.Action? { get }
  // TODO: Modify in place
}

extension WritableDomainScope {
  // TODO: Modify in place default implementation
}

public struct DirectDomainScope<ParentState, ParentAction, Child: Domain>: DomainScope {
  public let toChildState: (ParentState) -> (Child.State)?
//  public let fromChildAction: (inout ParentAction, Child.Action) -> Void
  public let fromChildAction: (Child.Action) -> (ParentAction)
  public init(
    state: @escaping (ParentState) -> (Child.State),
    action: @escaping (Child.Action) -> (ParentAction)
  ) {
    self.toChildState = state
    self.fromChildAction = action
//    self.fromChildAction = { $0 = action($1) }
  }
}

// TODO: Find a shorter name
public struct WritableDirectDomainScope<ParentState, ParentAction, Child: Domain>: DomainScope {
  public let toChildState: (ParentState) -> (Child.State)?

//  public let fromChildAction: (inout ParentAction, Child.Action) -> Void
  public let fromChildAction: (Child.Action) -> (ParentAction)

  public let fromChildState: (inout ParentState, Child.State) -> Void
  public let toChildAction: (ParentAction) -> Child.Action?

  @usableFromInline
  let file: StaticString
  @usableFromInline
  let fileID: StaticString
  @usableFromInline
  let line: UInt
  
  public init(
    state: WritableKeyPath<ParentState, Child.State>,
    action: CasePath<ParentAction, Child.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.toChildState = { $0[keyPath: state] }
//    self.fromChildAction = { $0 = action.embed($1) }
    self.fromChildAction = action.embed
    self.fromChildState = { $0[keyPath: state] = $1 }
    self.toChildAction = action.extract(from:)
    self.file = file
    self.fileID = fileID
    self.line = line
  }
}

extension WritableDirectDomainScope {
  public init(
    state: CasePath<ParentState, Child.State>,
    action: CasePath<ParentAction, Child.Action>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.toChildState = state.extract(from:)
//    self.fromChildAction = { $0 = action.embed($1) }
    self.fromChildAction = action.embed(_:)
    self.fromChildState = { $0 = state.embed($1) }
    self.toChildAction = action.extract(from:)
    self.file = file
    self.fileID = fileID
    self.line = line
  }
}
