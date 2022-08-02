#if DEBUG
import Combine
import SwiftUI
extension DebugEnvironment {
  static var sharedUIPrinter: DebugEnvironment {
    DebugUIPrinter.shared.debugEnvironment
  }

  final class DebugUIPrinter: ObservableObject {
    final class MessageAccumulator {
      @Published var messages: [Message] = [.init(id: -1, content: "")]
    }
    struct Message: Identifiable {
      var id: Int
      var content: String
    }
    static var shared = DebugUIPrinter()

    let accumulator: MessageAccumulator = .init()
    let baseEnvironment = DebugEnvironment()
    @Published var messages: [Message] = []
    var messagesCancellable: AnyCancellable?
    let processingQueue = DispatchQueue(
      label: "co.pointfree.ComposableArchitecture.DebugEnvironment.DebugUIPrinter",
      qos: .default
    )

    init() {
      messagesCancellable =
        accumulator.$messages
        .map { $0.suffix(1000).reversed() }
        .throttle(
          for: .milliseconds(100),
          scheduler: DispatchQueue.main,
          latest: true
        ).sink { [weak self] in
          self?.messages = $0
        }
    }

    var debugEnvironment: DebugEnvironment {
      .init { [baseEnvironment, processingQueue] string in
        var id: Int = 0
        processingQueue.async { [weak self] in
          for component in string.components(separatedBy: .newlines) {
            self?.accumulator.messages.append(.init(id: id, content: component))
            id += 1
          }
        }
        baseEnvironment.printer(string)
      }
    }
  }

  struct ReducerDebugView: View {
    var fontHeight: CGFloat
    @ObservedObject var printer: DebugEnvironment.DebugUIPrinter = .shared

    var body: some View {
      List {
        ForEach(printer.messages) { message in
          if #available(iOS 15.0, *) {
            Text(message.content)
              .listRowSeparator(.hidden)
          } else {
            Text(message.content)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(.init())
        .font(
          Font.system(size: fontHeight, weight: .semibold, design: .monospaced)
        )
        .scaleEffect(x: 1, y: -1)
      }
      .scaleEffect(x: 1, y: -1)
      .listStyle(.plain)
      .environment(\.defaultMinListRowHeight, fontHeight)
      .environment(\.colorScheme, .dark)
    }
  }
}
#endif
#if DEBUG
extension View {
  public func debugUI(
    _ alignment: Alignment = .bottom,
    height: CGFloat = 300,
    fontHeight: CGFloat = 10,
    opacity: CGFloat = 0.9
  ) -> some View {
    self.overlay(
      DebugEnvironment.ReducerDebugView(fontHeight: fontHeight)
        .opacity(opacity)
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: alignment)
    )
  }
}
#else
extension View {
  public func debugUI(
    _ alignment: Alignment = .bottom,
    height: CGFloat = 300,
    fontHeight: CGFloat = 10,
    opacity: CGFloat = 0.9
  ) -> some View {
    self
  }
}
#endif

extension Reducer {
  public func debugUI(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint
  ) -> Self {
    self.debugUI(
      prefix,
      state: { $0 },
      action: .self,
      actionFormat: actionFormat
    )
  }

  public func debugActionsUI(
    _ prefix: String = "",
    actionFormat: ActionFormat = .prettyPrint
  ) -> Self {
    self.debugUI(
      prefix,
      state: { _ in () },
      action: .self,
      actionFormat: actionFormat
    )
  }

  public func debugUI<LocalState, LocalAction>(
    _ prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    action toLocalAction: CasePath<Action, LocalAction>,
    actionFormat: ActionFormat = .prettyPrint
  ) -> Self {
    self.debug(
      prefix,
      state: toLocalState,
      action: toLocalAction,
      actionFormat: actionFormat,
      environment: { _ in
        #if DEBUG
        .sharedUIPrinter
        #else
        .init()
        #endif
      }
    )
  }
}
