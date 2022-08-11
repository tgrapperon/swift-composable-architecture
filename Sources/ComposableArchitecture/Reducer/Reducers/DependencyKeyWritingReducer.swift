extension ReducerProtocol {
  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> DependencyKeyWritingReducer<Self, Value> {
    .init(upstream: self) { $0[keyPath: keyPath] = value }
  }

  //  @inlinable
  //  public func transformDependency<Value>(
  //    _ keyPath: WritableKeyPath<DependencyValues, Value>,
  //    _ transform: @escaping (State, Action, inout Value) -> Void // Or only (inout Value) -> Void ?
  //  ) -> DependencyKeyWritingReducer<Self, Value> {
  //    .init(upstream: self) { state, action, values in
  //      var value = values[keyPath: keyPath]
  //      transform(state, action, &value)
  //      values[keyPath: keyPath] = value
  //    }
  //  }
  //
  //  @inlinable
  //  public func mapDependency<Source, Destination>(
  //    _ from: WritableKeyPath<DependencyValues, Source>,
  //    to other: WritableKeyPath<DependencyValues, Destination>,
  //    _ transform: @escaping (State, Action, Source) -> Destination // Or only (Source) -> Destination ?
  //  ) -> DependencyKeyWritingReducer<Self, Destination> {
  //    .init(upstream: self) { state, action, values in
  //      values[keyPath: other] = transform(state, action, values[keyPath: from])
  //    }
  //  }

  @inlinable
  public func transformDependency<Source, Destination>(
    _ from: WritableKeyPath<DependencyValues, Source>,
    into other: WritableKeyPath<DependencyValues, Destination>,
    transform: @escaping (Source, inout Destination) -> Void
  ) -> DependencyKeyWritingReducer<Self, Destination> {
    .init(upstream: self) { values in
      transform(values[keyPath: from], &values[keyPath: other])
    }
  }

  @inlinable
  public func bindStreamDependency<Source, Destination>(
    _ from: WritableKeyPath<DependencyValues, AsyncSharedStream<Source>>,
    to other: WritableKeyPath<DependencyValues, AsyncSharedStream<Destination>>,
    transform: @escaping (Source) -> Destination,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) -> DependencyKeyWritingReducer<Self, AsyncSharedStream<Destination>> {
    .init(upstream: self) { values in
      values[keyPath: from].bind(
        to: values[keyPath: other],
        transform: transform,
        file: file,
        line: line,
        column: column
      )
    }
  }
}

public struct DependencyKeyWritingReducer<Upstream: ReducerProtocol, Value>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let update: (inout DependencyValues) -> Void

  @usableFromInline
  init(upstream: Upstream, update: @escaping (inout DependencyValues) -> Void) {
    self.upstream = upstream
    self.update = update
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    var values = DependencyValues.current
    self.update(&values)
    return DependencyValues.$current.withValue(values) {
      self.upstream.reduce(into: &state, action: action)
    }
  }

  @inlinable
  public func dependency<Value>(
    _ keyPath: WritableKeyPath<DependencyValues, Value>,
    _ value: Value
  ) -> Self {
    .init(upstream: self.upstream) {
      self.update(&$0)
      $0[keyPath: keyPath] = value
    }
  }
}
