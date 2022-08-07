#if DEBUG
import Combine
import SwiftUI
extension DebugEnvironment {
  static var sharedUIPrinter: DebugEnvironment {
    DebugUIPrinter.shared.debugEnvironment
  }
}

final class DebugUIPrinter: ObservableObject {
  final class MessageAccumulator {

    @Published var messages: [Message] = []
    let processingQueue = DispatchQueue(
      label: "co.pointfree.ComposableArchitecture.DebugEnvironment.DebugUIPrinter",
      qos: .default
    )

    func print(_ message: String, color: Color? = nil) {
      processingQueue.async {
        self.messages.append(
          .init(
            id: self.messages.count,
            content: message,
            color: color ?? .primary
          )
        )
      }
    }
    
    func printDebugMessage(_ string: String) {
      processingQueue.async {
        for (index, component) in zip(0..., string.components(separatedBy: .newlines)) {
          var color: Color = .primary
          if index == 0 {
            color = .blue
          } else if component.starts(with: "+") {
            color = .green
          } else if component.starts(with: "-") {
            color = .red
          }
          self.messages.append(
            .init(
              id: self.messages.count,
              content: component,
              color: color,
              fontWeight: index == 0 ? .heavy : .semibold,
              isMessageHeader: index == 0
            )
          )
        }
      }
    }
  }
  
  struct Message: Identifiable {
    var id: Int
    var content: String
    var color: Color = .primary
    var fontWeight: Font.Weight = .medium
    var isMessageHeader: Bool = true
  }
  static var shared = DebugUIPrinter()

  let accumulator: MessageAccumulator = .init()
  let baseEnvironment = DebugEnvironment()
  lazy var debugEnvironment: DebugEnvironment = {
    return .init { [accumulator, baseEnvironment] string in
      accumulator.printDebugMessage(string)
      baseEnvironment.printer(string)
    }
  }()

  func print(_ message: String, color: Color? = nil) {
    accumulator.print(message, color: color)
  }

  @Published var messages: [Message] = []
  var messagesCancellable: AnyCancellable?

  init() {
    messagesCancellable =
      accumulator.$messages
      .map { $0.suffix(500).reversed() }
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
  let alignment: Alignment
  let width: CGFloat?
  let height: CGFloat?
  @State var offset: CGSize
  let opacity: CGFloat
  @ObservedObject var printer: DebugUIPrinter = .shared
  @State var consoleIsVisible: Bool = false
  @Environment(\.colorScheme) var defaultColorScheme

  var body: some View {
    ZStack(alignment: alignment) {
      if consoleIsVisible {
        consoleView
      }
      toggleButton
        .environment(\.colorScheme, consoleIsVisible ? .dark : defaultColorScheme)
    }
  }

  @ViewBuilder
  func row(message: DebugUIPrinter.Message) -> some View {
    Text(message.content)
      .font(
        Font.system(
          size: fontSize,
          weight: message.fontWeight,
          design: .monospaced
        )
      )
      .foregroundColor(message.color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(
        Group {
          if message.isMessageHeader {
            Divider()
              .frame(maxHeight: .infinity, alignment: .top)
          }
        }
      )
  }

  var consoleView: some View {
    List {
      ForEach(printer.messages) { message in
        #if os(iOS) || os(macOS)
        if #available(iOS 15, macOS 13, *) {
          row(message: message)
            .listRowSeparator(.hidden)
        } else {
          row(message: message)
        }
        #else
        row(message: message)
        #endif
      }
      .listRowInsets(.init())
      .scaleEffect(x: 1, y: -1)
    }
    .scaleEffect(x: 1, y: -1)
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, fontSize)
    .environment(\.colorScheme, .dark)
    .transition(
      alignment == .bottom
        ? .move(edge: .bottom)
        : alignment == .top
          ? .move(edge: .top)
          : .opacity
    )
    .opacity(opacity)
    .frame(width: width, height: height)
    .offset(offset)
  }

  var toggleButton: some View {
    Button {
      withAnimation(.easeOut(duration: 0.2)) {
        consoleIsVisible.toggle()
      }
    } label: {
      Image(systemName: "dock.rectangle")
        .imageScale(.large)
        .padding()
        .foregroundColor(.secondary)
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: alignment == .top ? .topTrailing : .bottomTrailing
    )
  }
}

public struct printUI {
  @discardableResult
  public init(_ message: String, color: Color? = nil) {
    DebugUIPrinter.shared.print(message, color: color)
  }
}

extension printUI: View {
  public var body: some View {
    EmptyView()
  }
}

//struct ReducerDebugView_Previews: PreviewProvider {
//  static let reducer = Reducer<Int, Int, Void> {
//    state, action, _ in
//    state = action * 2
//    return .none
//  }.debugUI()
//  static let store = Store(
//    initialState: 1,
//    reducer: reducer,
//    environment: ()
//  )
//
//  static var previews: some View {
//    NavigationView {
//      WithViewStore(store) { viewStore in
//        VStack {
//          Text("\(viewStore.state)")
//          Button("Double") {
//            viewStore.send(viewStore.state)
//          }
//        }
//      }
//    }.debugUI()
//  }
//}

#endif
extension View {
  /// Installs a virtual debug console that prints reducers's `.debugUI()` messages in SwiftUI
  /// Previews.
  ///
  /// You should use this method on the topmost view for a better experience. You also need to
  /// decorate the reducers you want to observe with `.debugUI()` methods.
  ///
  /// - Parameters:
  ///   - alignment: The alignment of the console, `.bottom` by default.
  ///   - width: The width of the console, `nil` by default.
  ///   - height: The height of the console, `300` by default.
  ///   - xOffset: An optional horizontal offset for the console.
  ///   - yOffset: An optional vertical offset for the console.
  ///   - scale: The scale used to display messages. You can lower it in domains with long
  ///   names.
  ///   - opacity: The opacity of the console, `0.9` by default.
  ///   - hidden: The initial state of the console. Set this value to `true` if you want to start
  ///   with a hidden console. Visibility is controlled by the toggle button that appear on the
  ///   trailing side
  /// - Returns: A `View` with a `debug` console displayed as an overlay.
  @ViewBuilder
  public func debugUI(
    _ alignment: Alignment = .bottom,
    width: CGFloat? = nil,
    height: CGFloat? = 300,
    xOffset: CGFloat = 0,
    yOffset: CGFloat = 0,
    scale: CGFloat = 1,
    opacity: CGFloat = 0.9,
    hidden: Bool = false
  ) -> some View {
    #if DEBUG
    self.overlay(
      ReducerDebugView(
        fontSize: 12 * scale,
        alignment: alignment,
        width: width,
        height: height,
        offset: .init(width: xOffset, height: yOffset),
        opacity: opacity,
        consoleIsVisible: !hidden
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    )
    #else
    self
    #endif
  }
}

extension Reducer {
  /// Same as `debug`, but where the environment is the shared UI debug console.
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

  /// Same as `debugActions`, but where the environment is the shared UI debug console.
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

  /// Same as `debug`, but where the environment is the shared UI debug console.
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
