extension Reducer {
  /// A reducer that re-evaluates synchronously individual `Effect(value:)` it generates.
  public func syncValues() -> Self {
    .init { state, action, environment in
      var action: Action? = action
      
      while let newAction = action {
        let effect = self.run(&state, newAction, environment)
        guard case let .value(syncAction) = effect else {
          return effect
        }
        action = syncAction
      }
      fatalError()
    }
  }
}
