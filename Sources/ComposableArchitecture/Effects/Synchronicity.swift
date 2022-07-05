extension Reducer {
  /// A reducer that re-evaluates synchronously individual `Effect(value:)` it generates.
  public func syncFeedback() -> Self {
    .init { state, action, environment in
      var action: Action? = action
      
      while let syncAction = action {
        let effect = self.run(&state, syncAction, environment)
        guard case let .value(syncAction) = effect else {
          return effect
        }
        action = syncAction
      }
      fatalError()
    }
  }
}
