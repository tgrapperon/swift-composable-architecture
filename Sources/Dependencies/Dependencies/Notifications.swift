import Foundation

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension DependencyValues {
  public var notifications: NotificationStreamOf {
    get { self[NotificationStreamOf.self] }
    set { self[NotificationStreamOf.self] = newValue }
  }
}

extension Notification {
  /// Used as a namespace to host read-only NotificationDependency
  public struct Dependencies {
    public typealias Dependency = Notification.Dependency
    init() {}
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
@dynamicMemberLookup
public struct NotificationStreamOf: DependencyKey {
  private static var notifications: [Notification.Dependencies.ID: Any] = [:]
  private static var lock = NSRecursiveLock()

  public static var liveValue: NotificationStreamOf { .init() }
  // TODO: make it unimplemented by default
  public static var testValue: NotificationStreamOf { .init() }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<Notification.Dependencies, Notification.Dependency<Value>>
  )
    -> Notification.Stream<Value>
  {
    get {
      let dependency = Notification.Dependencies()[keyPath: keyPath]
      Self.lock.lock()
      defer { Self.lock.unlock() }
      if let existing = Self.notifications[dependency.id] as? Notification.Stream<Value> {
        return existing
      }
      let stream = Notification.Stream<Value>(dependency, source: .notifications)
      Self.notifications[dependency.id] = stream
      return stream
    }
    nonmutating set {
      let dependency = Notification.Dependencies()[keyPath: keyPath]
      Self.lock.lock()
      defer { Self.lock.unlock() }
      Self.notifications[dependency.id] = newValue
    }
  }
}

extension Notification.Dependencies {
  struct ID: Hashable, Sendable {
    let key: Notification.Name
    let object: ObjectIdentifier?
    let file: String
    let line: UInt
    let type: ObjectIdentifier
  }
}

extension Notification {
  public struct Dependency<Value: Sendable>: @unchecked Sendable {
    let key: Notification.Name
    let object: AnyObject?
    let transform: @Sendable (Notification) async throws -> Value
    let file: StaticString
    let line: UInt

    public init(
      _ key: Notification.Name,
      object: AnyObject? = nil,
      transform: @Sendable @escaping (Notification) async throws -> Value,
      file: StaticString = #fileID,
      line: UInt = #line
    ) {
      self.key = key
      self.object = object
      self.transform = transform
      self.file = file
      self.line = line
    }

    // Case where (Notification) -> Void
    public init(
      _ key: Notification.Name,
      object: AnyObject? = nil,
      file: StaticString = #fileID,
      line: UInt = #line
    ) where Value == Void {
      self.key = key
      self.object = object
      self.transform = { _ in () }
      self.file = file
      self.line = line
    }

    var id: Notification.Dependencies.ID {
      .init(
        key: key,
        object: object.map(ObjectIdentifier.init),
        file: file.description,
        line: line,
        type: ObjectIdentifier(Value.self)
      )
    }

    // We can lower all iOS 15 requirements to iOS 13 using Combine or even old-school notification
    // observation.
    // TODO: There are too much methods to make a `NotificationStream` controllable.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    public var controllable: Stream<Value> {
      Stream(self, source: .controllable)
    }
  }
}

private var continuationsLock = NSRecursiveLock()
private var continuations: [ContinuationID: Any] = [:]

private struct ContinuationID: Hashable {
  let uuid: UUID
  let notificationID: Notification.Dependencies.ID
}

extension Notification {
  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  public struct Stream<Value: Sendable>: Sendable {
    enum Source {
      case notifications
      case controllable
    }

    private var source: Source = .notifications
    private let notificationDependency: Dependency<Value>

    init(_ notificationDependency: Dependency<Value>, source: Source) {
      self.notificationDependency = notificationDependency
      self.source = source
    }

    // allows teststore.depdencies.notifications.makeControllable()
    public mutating func makeControllable() {
      self = Self.controllable(notificationDependency)
    }
    // allows .dependency(\.notifications[xxx], .controllable(xxx))
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    public static func controllable(_ notification: Dependency<Value>)
      -> Stream<Value>
    {
      Stream(notification, source: .controllable)
    }

    // TODO: Make NotificationStream itself an AsyncSequence instead?
    public func callAsFunction() -> AsyncStream<Value> {
      switch self.source {
      case .notifications:
        return AsyncStream(Value.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
          let task = Task {
            for await notification in NotificationCenter.default.notifications(
              named: self.notificationDependency.key)
            {
              do {
                let value = try await self.notificationDependency.transform(notification)
                continuation.yield(value)
              } catch {
                continuation.finish()
              }
            }
          }
          continuation.onTermination = { _ in
            task.cancel()
          }
        }
      case .controllable:
        return AsyncStream(Value.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
          let id = ContinuationID(uuid: .init(), notificationID: self.notificationDependency.id)
          continuationsLock.lock()
          continuations[id] = continuation
          continuationsLock.unlock()

          continuation.onTermination = { _ in
            continuationsLock.lock()
            defer { continuationsLock.unlock() }
            continuations[id] = nil
          }
        }
      }
    }

    public func send(_ value: Value) {
      guard source == .controllable else {
        /// TODO: Improve with #file, etc.
        runtimeWarn("Trying to control a notification-based dependency. This is not supported.")
        return
      }
      let id = self.notificationDependency.id
      continuationsLock.lock()
      for continuation in continuations.filter({ $0.key.notificationID == id }).values {
        (continuation as! AsyncStream<Value>.Continuation).yield(value)
      }
      continuationsLock.unlock()
    }

    public func send() where Value == Void {
      self.send(())
    }
  }
}
