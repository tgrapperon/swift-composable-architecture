import Foundation

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension DependencyValues {
  public var notifications: NotificationStreamOf {
    get { self[NotificationStreamOf.self] }
    set { self[NotificationStreamOf.self] = newValue }
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
public struct NotificationStreamOf: DependencyKey {
  static var notifications: [NotificationDependencyID: Any] = [:]
  static var lock = NSRecursiveLock()
  public static var liveValue: NotificationStreamOf { .init() }
  public static var testValue: NotificationStreamOf { .init() }
  
  public subscript<Value>(_ notificationDependency: NotificationDependency<Value>)
    -> NotificationStream<Value>
  {
    get {
      Self.lock.lock()
      defer { Self.lock.unlock() }
      if let existing = Self.notifications[notificationDependency.id] as? NotificationStream<Value>
      {
        return existing
      }
      let stream = NotificationStream<Value>(notificationDependency, source: .notifications)
      Self.notifications[notificationDependency.id] = stream
      return stream
    }
    set {
      Self.lock.lock()
      defer { Self.lock.unlock() }
      Self.notifications[notificationDependency.id] = newValue
    }
  }
}

struct NotificationDependencyID: Hashable, Sendable {
  let key: Notification.Name
  let object: ObjectIdentifier?
  let file: String
  let line: UInt
  let type: ObjectIdentifier
}

public struct NotificationDependency<Value: Sendable>: @unchecked Sendable, Hashable {
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

  var id: NotificationDependencyID {
    .init(
      key: key,
      object: object.map(ObjectIdentifier.init),
      file: file.description,
      line: line,
      type: ObjectIdentifier(Value.self)
    )
  }

  var controlledNotificationName: Notification.Name {
    .init(
      [
        self.key.rawValue,
        String(describing: self.object.map(ObjectIdentifier.init)),
        self.file.description,
        "\(self.line)",
        "\(ObjectIdentifier(Value.self))",
      ].joined(separator: ":")
    )
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    guard
      lhs.key == rhs.key,
      lhs.file.description == rhs.file.description,
      lhs.line == rhs.line
    else {
      return false
    }
    return true
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.key)
    hasher.combine(self.file.description)
    hasher.combine(self.line)
  }

  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  public var controllable: NotificationStream<Value> {
    let dependency = NotificationDependency(self.controlledNotificationName) {
      $0.userInfo![""]! as! Value
    }
    return NotificationStream(dependency, source: .controllable)
  }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
public struct NotificationStream<Value> {
  enum Source {
    case notifications
    case controllable
  }

  private var source: Source = .notifications
  private let notificationDependency: NotificationDependency<Value>

  init(_ notificationDependency: NotificationDependency<Value>, source: Source) {
    self.notificationDependency = notificationDependency
    self.source = source
  }

  public mutating func makeControllable() {
    self = Self.controllable(notificationDependency)
  }

  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  public static func controllable(_ notification: NotificationDependency<Value>)
    -> NotificationStream<Value>
  {
    let dependency = NotificationDependency(notification.controlledNotificationName) {
      $0.userInfo![""]! as! Value
    }
    return NotificationStream(dependency, source: .controllable)
  }

  public func callAsFunction() -> AsyncStream<Value> {
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
  }

  public func send(_ value: Value) async {
    guard source == .notifications else {
      print("Trying to control a notification-based dependency. This is not supported.")
      return
    }
    NotificationCenter.default.post(
      name: notificationDependency.controlledNotificationName,
      object: nil,
      userInfo: ["": value]
    )
  }
}
