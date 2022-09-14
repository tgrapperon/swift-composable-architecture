extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on an optional property of parent state.
  ///
  /// - Parameters:
  ///   - toWrappedState: A writable key path from parent state to a property containing optional
  ///     child state.
  ///   - toWrappedAction: A case path from parent action to a case containing child actions.
  ///   - wrapped: A reducer that will be invoked with child actions against non-optional child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  public func ifLet<Wrapped: ReducerProtocol>(
    _ toWrappedState: WritableKeyPath<State, Wrapped.State?>,
    action toWrappedAction: CasePath<Action, Wrapped.Action>,
    @ReducerBuilderOf<Wrapped> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, Wrapped> {
    .init(
      parent: self,
      child: wrapped(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }
  
  @inlinable
  public func ifLet<Wrapped: ReducerProtocol>(
    _ scope: WritableDirectDomainScope<State, Action, Wrapped?>,
    @ReducerBuilderOf<Wrapped> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, Wrapped> {
    .init(
      parent: self,
      child: wrapped(),
      scope: scope
    )
  }
}

public struct _IfLetReducer<Parent: ReducerProtocol, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let domainScope: WritableDirectDomainScope<Parent.State, Parent.Action, Child?>

  @inlinable
  init(
    parent: Parent,
    child: Child,
    toChildState: WritableKeyPath<Parent.State, Child.State?>,
    toChildAction: CasePath<Parent.Action, Child.Action>,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.child = child
    self.domainScope = .init(
      state: toChildState,
      action: toChildAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }
  
  @inlinable
  init(
    parent: Parent,
    child: Child,
    scope: WritableDirectDomainScope<Parent.State, Parent.Action, Child?>
  ) {
    self.parent = parent
    self.child = child
    self.domainScope = scope
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    self.reduceChild(into: &state, action: action)
      .merge(with:  self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let childAction = self.domainScope.toChildAction(action)
    else { return .none }
    guard (try! self.domainScope.derived().toChildState(state)) != nil else {
      runtimeWarning(
        """
        An "ifLet" at "%@:%d" received a child action when child state was "nil". …

          Action:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set child state to "nil" before this reducer ran. This reducer must \
        run before any other reducer sets child state to "nil". This ensures that child reducers \
        can handle their actions while their state is still available.

        • An in-flight effect emitted this action when child state was "nil". While it may be \
        perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state becomes "nil", especially if it is a long-living effect.

        • This action was sent to the store while state was "nil". Make sure that actions for this \
        reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
        applications, use "IfLetStore".
        """,
        [
          "\(self.domainScope.fileID)",
          self.domainScope.line,
          debugCaseOutput(action),
          typeName(Child.State.self),
        ],
        file: self.domainScope.file,
        line: self.domainScope.line
      )
      return .none
    }
    return try! self.domainScope.modify(&state) {
      self.child.reduce(into: &$0!, action: childAction)
    }.map(self.domainScope.fromChildAction)
  }
}
