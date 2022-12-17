import Dependencies

@propertyWrapper
public struct SubscriptionStateOf<Value> {
  public init(wrappedValue: Value? = nil) {
    self.wrappedValue = wrappedValue
  }
  public var wrappedValue: Value?
  public var projectedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }
}

public enum SubscriptionActionOf<Value> {
  case onReceive(TaskResult<Value>)
  case startObserving
  case stopObserving
}

// TODO: Make a modifier to scope onto `SubscriptionStateOf`?
// TODO: Find a way to handle better `Value` vs `Value?`

public struct SubscriptionReducer<Value>: ReducerProtocol {
  public typealias State = SubscriptionStateOf<Value>
  public typealias Action = SubscriptionActionOf<Value>

  public let cancelInFlight: Bool
  public let id: AnyHashable
  let subscription: (Value?) -> EffectTask<Action>

  public init<S: AsyncSequence, ID: Hashable>(
    to sequence: KeyPath<DependencyValues, @Sendable () async -> S>,
    id: ID,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil,
    reduce: @Sendable @escaping (Value?, S.Element) async throws -> Value
  ) {
    self.id = id
    self.cancelInFlight = cancelInFlight

    self.subscription = Self.subscription(
      sequence: {
        let sequence = Dependency(sequence).wrappedValue
        return await sequence()
      },
      priority: priority
    ) {
      try await reduce($0, $1)
    }
  }

  public init<S: AsyncSequence, ID: Hashable>(
    to sequence: KeyPath<DependencyValues, S>,
    id: ID,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil,
    reduce: @Sendable @escaping (Value?, S.Element) async throws -> Value
  ) {
    self.id = id
    self.cancelInFlight = cancelInFlight

    self.subscription = Self.subscription(
      sequence: sequence,
      priority: priority
    ) {
      try await reduce($0, $1)
    }
  }

  public static func subscription<S: AsyncSequence>(
    sequence: KeyPath<DependencyValues, S>,
    priority: TaskPriority?,
    reduce: @escaping (Value?, S.Element) async throws -> Value
  ) -> (Value?) -> EffectTask<Action> {
    return subscription(
      sequence: {
        let sequence = Dependency(sequence).wrappedValue
        return sequence
      },
      priority: priority,
      reduce: reduce)
  }

  public static func subscription<S: AsyncSequence>(
    sequence: KeyPath<DependencyValues, () async throws -> S>,
    priority: TaskPriority?,
    reduce: @escaping (Value?, S.Element) async throws -> Value
  ) -> (Value?) -> EffectTask<Action> {
    return subscription(
      sequence: {
        let sequence = Dependency(sequence).wrappedValue
        return try await sequence()
      },
      priority: priority,
      reduce: reduce)
  }

  public static func subscription<S: AsyncSequence>(
    sequence: @Sendable @escaping () async throws -> S,
    priority: TaskPriority?,
    reduce: @escaping (Value?, S.Element) async throws -> Value
  ) -> (Value?) -> EffectTask<Action> {
    return { initialValue in
      // Using @Dependency crashes the compiler
      return .run(priority: priority) { send in
        var currentValue = initialValue
        for try await element in try await sequence() {
          let newValue = try await reduce(currentValue, element)
          defer { currentValue = newValue }
          await send(.onReceive(.success(newValue)))
        }
      } catch: { error, send in
        await send(.onReceive(.failure(error)))
      }
    }
  }

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case let .onReceive(.success(value)):
      state.wrappedValue = value
      return .none

    case .onReceive:
      return .none

    case .startObserving:
      return self.subscription(state.wrappedValue)
        .cancellable(id: id, cancelInFlight: cancelInFlight)

    case .stopObserving:
      return .cancel(id: id)
    }
  }
}

extension SubscriptionStateOf: Equatable where Value: Equatable {}
extension SubscriptionStateOf: Hashable where Value: Hashable {}
extension SubscriptionStateOf: Sendable where Value: Sendable {}
extension SubscriptionStateOf: Codable where Value: Codable {}

extension SubscriptionActionOf: Equatable where Value: Equatable {}
extension SubscriptionActionOf: Hashable where Value: Hashable {}
extension SubscriptionActionOf: Sendable where Value: Sendable {}

extension SubscriptionReducer {
  public init<S: AsyncSequence, ID: Hashable>(
    to sequence: KeyPath<DependencyValues, @Sendable () async -> S>,
    id: ID,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil,
    transform: @Sendable @escaping (S.Element) async throws -> Value
  ) {
    self.init(to: sequence, id: id) {
      try await transform($1)
    }
  }

  public init<S: AsyncSequence, ID: Hashable>(
    to sequence: KeyPath<DependencyValues, @Sendable () async -> S>,
    id: ID,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil
  ) where S.Element == Value {
    self.init(to: sequence, id: id) { $1 }
  }

  public init<S: AsyncSequence>(
    to sequence: KeyPath<DependencyValues, @Sendable () async -> S>,
    id: Any.Type,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil,
    transform: @Sendable @escaping (S.Element) async throws -> Value
  ) {
    self.init(to: sequence, id: ObjectIdentifier(id)) {
      try await transform($1)
    }
  }

  public init<S: AsyncSequence>(
    to sequence: KeyPath<DependencyValues, @Sendable () async -> S>,
    id: Any.Type,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil
  ) where S.Element == Value {
    self.init(to: sequence, id: ObjectIdentifier(id)) { $1 }
  }
}

extension SubscriptionReducer {
  public init<S: AsyncSequence, ID: Hashable>(
    to sequence: KeyPath<DependencyValues, S>,
    id: ID,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil,
    transform: @Sendable @escaping (S.Element) async throws -> Value
  ) {
    self.init(to: sequence, id: id) {
      try await transform($1)
    }
  }

  public init<S: AsyncSequence, ID: Hashable>(
    to sequence: KeyPath<DependencyValues, S>,
    id: ID,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil
  ) where S.Element == Value {
    self.init(to: sequence, id: id) { $1 }
  }

  public init<S: AsyncSequence>(
    to sequence: KeyPath<DependencyValues, S>,
    id: Any.Type,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil,
    transform: @Sendable @escaping (S.Element) async throws -> Value
  ) {
    self.init(to: sequence, id: ObjectIdentifier(id)) {
      try await transform($1)
    }
  }

  public init<S: AsyncSequence>(
    to sequence: KeyPath<DependencyValues, S>,
    id: Any.Type,
    cancelInFlight: Bool = false,
    priority: TaskPriority? = nil
  ) where S.Element == Value {
    self.init(to: sequence, id: ObjectIdentifier(id)) { $1 }
  }
}
