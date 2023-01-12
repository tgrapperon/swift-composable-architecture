import Dependencies
import Foundation
import OrderedCollections
import TabularData

@_spi(Instruments) public final class Instrumentation {
  public struct Event: Hashable, Sendable {
    public struct Tag: Hashable, Sendable {
      let subject: Subject
      let label: String
      let fileID: StaticString
      let line: UInt
      public static func == (lhs: Self, rhs: Self) -> Bool {
        guard
          lhs.subject == rhs.subject,
          lhs.label == rhs.label,
          lhs.fileID.description == rhs.fileID.description,
          lhs.line == rhs.line
        else { return false }
        return true
      }
      public func hash(into hasher: inout Hasher) {
        hasher.combine(self.subject)
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

  public enum Subject: Hashable, Sendable, CustomStringConvertible {
    case none
    case store
    case viewstore
    case reducer
    case view
    case other(String)
    public var description: String {
      switch self {
      case .none:
        return ""
      case .store:
        return "Store"
      case .viewstore:
        return "ViewStore"
      case .reducer:
        return "Reducer"
      case .view:
        return "View"
      case .other(let other):
        return other
      }
    }
  }
  public enum LifecycleEvent: String, Hashable, Sendable {
    case body
    case `deinit`
    case `init`
    case objectWillChange = "willChange"
    case scope
    case send
  }

  public static let shared: Instrumentation = Instrumentation()

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

  public func log(
    _ label: @autoclosure () -> String,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    guard self.isEnabled else { return }
    let tag = Event.Tag(subject: .none, label: label(), fileID: fileID, line: line)
    events[tag, default: []].append(
      Event(
        tag: tag,
        payload: .none,
        date: Date(),
        timestamp: ProcessInfo.processInfo.systemUptime
      )
    )
  }

  public func log(
    _ label: @autoclosure () -> String,
    subject: Subject,
    event: LifecycleEvent,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    guard self.isEnabled else { return }
    let tag = Event.Tag(subject: subject, label: label(), fileID: fileID, line: line)
    events[tag, default: []].append(
      Event(
        tag: tag,
        payload: .lifecycle(event),
        date: Date(),
        timestamp: ProcessInfo.processInfo.systemUptime
      )
    )
    self.print()
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

extension Instrumentation.Event {
  var lifecycleEvent: Instrumentation.LifecycleEvent? {
    if case let .lifecycle(event) = self.payload {
      return event
    }
    return nil
  }
}

let instrumentationQueue = DispatchQueue(
  label: "co.pointfree.swift-composable-architecture.instruments")
extension Instrumentation {

  public func print() {
    guard self.isEnabled else { return }
    instrumentationQueue.async { [events] in
      processEvents(events)
    }
  }
}
private typealias Events = OrderedDictionary<Instrumentation.Event.Tag, [Instrumentation.Event]>

func processEvents(_ events: OrderedDictionary<Instrumentation.Event.Tag, [Instrumentation.Event]>)
{
  struct Row {
    let label: String
    let subject: Instrumentation.Subject
    let lifecycleEvent: Instrumentation.LifecycleEvent
    var count: Int
  }
  var rows = [Row]()
  for _events in events.values {
    for event in _events {
      if let index = rows.firstIndex(where: {
        $0.label == event.tag.label
        && $0.lifecycleEvent == event.lifecycleEvent
          && $0.subject == event.tag.subject
      }) {
        rows[index].count += 1
      } else if let lifecycleEvent = event.lifecycleEvent {
        rows.append(.init(label: event.tag.label, subject: event.tag.subject, lifecycleEvent: lifecycleEvent, count: 0))
      }
    }
  }
  if #available(iOS 15, *) {
    let columns = ["Subject", "Type", "Event", "Count"]
    let csv =
      ([columns.joined(separator: ",")]
      + rows
      .sorted(using: KeyPathComparator(\.label)).map {
        "\"\($0.subject)\",\"\($0.label)\",\($0.lifecycleEvent.rawValue),\($0.count)"
      }).joined(separator: "\n")
    do {
      let dataFrame = try DataFrame(csvData: csv.data(using: .utf8)!, columns: columns)
      print(dataFrame.description(options: .init(maximumLineWidth: 200, includesColumnTypes: true)))
    } catch {
      print(error)
    }
  }
}
