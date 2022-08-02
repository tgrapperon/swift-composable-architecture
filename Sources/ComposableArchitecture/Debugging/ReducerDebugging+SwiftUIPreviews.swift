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
    lazy var debugEnvironment: DebugEnvironment = {
      var id: Int = 0
      return .init { [baseEnvironment, processingQueue] string in
        processingQueue.async { [weak self] in
          for component in string.components(separatedBy: .newlines) {
            self?.accumulator.messages.append(.init(id: id, content: component))
            id += 1
          }
        }
        baseEnvironment.printer(string)
      }
    }()
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
  }

  struct ReducerDebugView: View {
    let fontSize: CGFloat
    let lightweight: Bool
    @ObservedObject var printer: DebugEnvironment.DebugUIPrinter = .shared

    func textColor(_ string: String) -> Color? {
      if string.starts(with: "+") { return .green }
      if string.starts(with: "-") { return .red }
      if string.starts(with: "received action:") { return .blue }
      return nil
    }

    func fontWeight(_ string: String) -> Font.Weight {
      if string.starts(with: "received action:") { return .bold }
      return .semibold
    }

    func font(_ string: String) -> Font {
      if string.starts(with: "received action:") {
        return Font.system(size: fontSize, weight: .heavy, design: .monospaced)
      }
      return Font.system(size: fontSize, weight: .semibold, design: .monospaced)
    }

    @ViewBuilder
    func row(_ string: String) -> some View {
      if lightweight {
        Text(string)
          .frame(maxWidth: .infinity, alignment: .leading)
          .font(Font.system(size: fontSize, weight: .semibold, design: .monospaced))
      } else {
        Text(string)
          .font(self.font(string))
          .foregroundColor(textColor(string))
          .frame(maxWidth: .infinity, alignment: .leading)
          .overlay(
            Group {
              if string.starts(with: "received action:") {
                Divider().frame(maxHeight: .infinity, alignment: .top)
              }
            }
          )
      }
    }

    var body: some View {
      List {
        ForEach(printer.messages) { message in
          if #available(iOS 15.0, *) {
            row(message.content)
              .listRowSeparator(.hidden)
          } else {
            row(message.content)
          }
        }
        .listRowInsets(.init())
        .scaleEffect(x: 1, y: -1)
      }
      .scaleEffect(x: 1, y: -1)
      .listStyle(.plain)
      .environment(\.defaultMinListRowHeight, fontSize)
      .environment(\.colorScheme, .dark)
    }
  }
}
#endif
#if DEBUG
extension View {
  public func debugUI(
    _ alignment: Alignment = .bottom,
    width: CGFloat? = nil,
    height: CGFloat? = 300,
    xOffset: CGFloat = 0,
    yOffset: CGFloat = 0,
    fontSize: CGFloat = 10,
    opacity: CGFloat = 0.9,
    lightweight: Bool = false
  ) -> some View {
    self.overlay(
      DebugEnvironment.ReducerDebugView(fontSize: fontSize, lightweight: lightweight)
        .opacity(opacity)
        .frame(width: width, height: height)
        .offset(x: xOffset, y: yOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    )
  }
}
#else
extension View {
  public func debugUI(
    _ alignment: Alignment = .bottom,
    width: CGFloat? = nil,
    height: CGFloat? = 300,
    xOffset: CGFloat = 0,
    yOffset: CGFloat = 0,
    fontSize: CGFloat = 10,
    opacity: CGFloat = 0.9,
    lightweight: Bool = false
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
