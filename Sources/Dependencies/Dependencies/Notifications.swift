import Foundation
import XCTestDynamicOverlay

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension DependencyValues {
  public var notifications: Notification.StreamOf {
    get { self[Notification.StreamOf.self] }
    set { self[Notification.StreamOf.self] = newValue }
  }
}

extension Notification {
  /// Used as a namespace to host read-only Notification.Dependency's
  public struct DependencyValues {
    // This helps to disambiguate with Dependencies.Dependency when defining the read-only
    // Notification.Dependency
    public typealias Dependency = Notification.Dependency
    init() {}
  }
}

extension Notification {
  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  @dynamicMemberLookup
  public struct StreamOf: DependencyKey, Sendable {
    private static var notifications: [DependencyValues.ID: Any] = [:]
    private static var lock = NSRecursiveLock()
    
    public static var liveValue: StreamOf { .init() }
    public static var testValue: StreamOf { .init() }

    @Dependencies.Dependency(\.context) var context
    
    public subscript<Value>(
      dynamicMember keyPath: KeyPath<DependencyValues, Dependency<Value>>
    )
      -> Stream<Value>
    {
      get {
        let dependency = DependencyValues()[keyPath: keyPath]
        Self.lock.lock()
        defer { Self.lock.unlock() }
        if let existing = Self.notifications[dependency.id] as? Notification.Stream<Value> {
          return existing
        }
        if context == .test {
          let message = """
          Unimplemented: Notification.Dependency for \(dependency.key.rawValue)…
          
          The Notification dependency observing \(dependency.key.rawValue) defined at \
          \(dependency.file):\(dependency.line) is not implemented in a test context.
          
          You can assign an explicit `Notification.Stream`, or make the default one controllable \
          by calling `.makeControllable()` directly on the dependency, or by assigning \
          `.controllable(\\.foo)` to the dependency `\\.notifications.foo`.
          """
          XCTFail(message)
        }
        let stream = Notification.Stream<Value>(dependency)
        Self.notifications[dependency.id] = stream
        return stream
      }
      nonmutating set {
        let dependency = Notification.DependencyValues()[keyPath: keyPath]
        Self.lock.lock()
        defer { Self.lock.unlock() }
        Self.notifications[dependency.id] = newValue
      }
    }
  }
}

extension Notification.DependencyValues {
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

    var id: Notification.DependencyValues.ID {
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
  let notificationID: Notification.DependencyValues.ID
}

extension Notification {
  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  public struct Stream<Value: Sendable>: Sendable {
    enum Source {
      case notifications
      case controllable
    }

    // Warning: Dependency = Notification.Dependency, DependencyValues = Notification.Dependency
    private let dependency: Dependency<Value>
    private var source: Source = .notifications

    init(_ dependency: Dependency<Value>, source: Source = .notifications) {
      self.dependency = dependency
      self.source = source
    }

    // allows teststore.depdencies.notifications.makeControllable()
    public mutating func makeControllable() {
      self.source = .controllable
    }
    
    // allows .dependency(\.notifications.xxx, .controllable(\.xxx))
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    public static func controllable(_ keyPath: KeyPath<DependencyValues, Dependency<Value>>)
      -> Stream<Value>
    {
      Stream(DependencyValues()[keyPath: keyPath], source: .controllable)
    }

    // TODO: Make NotificationStream itself an AsyncSequence instead?
    public func callAsFunction() -> AsyncStream<Value> {
      switch self.source {
      case .notifications:
        return AsyncStream(Value.self, bufferingPolicy: .bufferingNewest(1)) { continuation in
          let task = Task {
            for await notification in NotificationCenter.default.notifications(
              named: self.dependency.key)
            {
              do {
                let value = try await self.dependency.transform(notification)
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
          let id = ContinuationID(uuid: .init(), notificationID: self.dependency.id)
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

    public func post(_ value: Value) {
      guard source == .controllable else {
        /// TODO: Improve with #file, etc.
        XCTFail("""
          Trying to control a notification-based dependency. This is not supported.
          
          You can only control a notification stream that was made controllable using \
          `.makeControllable()` or defined as `.controllable(\\.foo)`.
          """
        )
        return
      }
      let id = self.dependency.id
      continuationsLock.lock()
      for continuation in continuations.filter({ $0.key.notificationID == id }).values {
        (continuation as! AsyncStream<Value>.Continuation).yield(value)
      }
      continuationsLock.unlock()
    }

    public func post() where Value == Void {
      self.post(())
    }
  }
}
