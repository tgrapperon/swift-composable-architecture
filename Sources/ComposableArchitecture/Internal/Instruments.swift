import Dependencies
import Foundation
import OrderedCollections

@_spi(Instrumentation) public final class Instrumentation {
  public struct Event: Hashable, Sendable {
    public struct Tag: Hashable, Sendable {
      let label: String
      let fileID: StaticString
      let line: UInt
      public static func == (lhs: Self, rhs: Self) -> Bool {
        guard
          lhs.label == rhs.label,
          lhs.fileID.description == rhs.fileID.description,
          lhs.line == rhs.line
        else { return false }
        return true
      }
      public func hash(into hasher: inout Hasher) {
        hasher.combine(self.label)
        hasher.combine(self.fileID.description)
        hasher.combine(self.line)
      }
    }
    let tag: Tag
    let payload: Payload
    let date: Date
    let timestamp: TimeInterval
  }
  
  public enum Payload: Hashable, Sendable {
    case none
    case integer(Int)
    case string(String)
    case date(Date)
    case lifecycle(LifecycleEvent)
  }
  
  public enum LifecycleEvent: Hashable, Sendable {
    case body
    case `deinit`
    case `init`
    case objectWillChange
    case scope
    case send
  }
  
  public var shared: Instrumentation = Instrumentation()
  
  private var _isEnabled: Bool = false

  private let eventsStreamAndContinuations = AsyncStream<
    OrderedDictionary<Event.Tag, [Event]>
  >
  .streamWithContinuation(bufferingPolicy: .bufferingNewest(1))

  private var events: OrderedDictionary<Event.Tag, [Event]> = [:] {
    didSet {
      eventsStreamAndContinuations.continuation.yield(events)
    }
  }
  public var eventsStream: AsyncStream<OrderedDictionary<Event.Tag, [Event]>> {
    eventsStreamAndContinuations.stream
  }
  public var isEnabled: Bool {
    guard Thread.isMainThread else { return false }
    return _isEnabled
  }
  public func enable() {
    guard Thread.isMainThread else { return }
    _isEnabled = true
  }

  func log(
    _ label: @autoclosure () -> String,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    guard self.isEnabled else { return }
    let tag = Event.Tag(label: label(), fileID: fileID, line: line)
    events[tag, default: []].append(
      Event(
        tag: tag,
        payload: .none,
        date: Date(),
        timestamp: ProcessInfo.processInfo.systemUptime
      )
    )
  }
  
  public func clearEvents() {
    guard isEnabled else { return }
    self.events = [:]
  }
}

extension Instrumentation.Event: Identifiable {
  public var id: Tag { self.tag }
}

extension Instrumentation.Event: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.timestamp < rhs.timestamp
  }
}

extension Instrumentation {
  public func print() {
    guard self.isEnabled else { return }
    Swift.print(events)
  }
}
