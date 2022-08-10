extension ReducerProtocol {
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self) { _, _, values in values[keyPath: keyPath] = value }
  }
  
  @inlinable
  public func transformDependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ transform: @escaping (State, Action, inout Value) -> Void // Or only (inout Value) -> Void ?
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self) { state, action, values in
      var value = values[keyPath: keyPath]
      transform(state, action, &value)
      values[keyPath: keyPath] = value
    }
  }
  
  @inlinable
  public func mapDependency<Source, Destination>(
    _ from: WritableKeyPath<DependencyValues, Source>,
    to other: WritableKeyPath<DependencyValues, Destination>,
    _ transform: @escaping (State, Action, Source) -> Destination // Or only (Source) -> Destination ?
  ) -> DependencyKeyWritingReducer<Self, Destination> {
    .init(upstream: self) { state, action, values in
      values[keyPath: other] = transform(state, action, values[keyPath: from])
    }
  }
  
  @inlinable
  public func transformDependency<Source, Destination>(
    _ from: WritableKeyPath<DependencyValues, Source>,
    into other: WritableKeyPath<DependencyValues, Destination>,
    _ transform: @escaping (State, Action, Source, inout Destination) -> Void // Or only (Source, Destination) -> Void ?
  ) -> DependencyKeyWritingReducer<Self, Destination> {
    .init(upstream: self) { state, action, values in
      transform(state, action, values[keyPath: from], &values[keyPath: other])
    }
  }
}

public struct DependencyKeyWritingReducer<Upstream: ReducerProtocol, Value>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let update: (Upstream.State, Upstream.Action, inout DependencyValues) -> Void

  @usableFromInline
  init(upstream: Upstream, update: @escaping (Upstream.State, Upstream.Action, inout DependencyValues) -> Void) {
    self.upstream = upstream
    self.update = update
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    var values = DependencyValues.current
    self.update(state, action, &values)
    return DependencyValues.$current.withValue(values) {
      self.upstream.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(upstream: self.upstream) { state, action, values in
      self.update(state, action, &values)
      values[keyPath: keyPath] = value
    }
  }
}
