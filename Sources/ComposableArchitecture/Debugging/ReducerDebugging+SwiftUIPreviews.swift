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
  }
  struct Message: Identifiable {
    var id: Int
    var content: String
    var color: Color
    var isHeader: Bool
  }
  static var shared = DebugUIPrinter()

  let accumulator: MessageAccumulator = .init()
  let baseEnvironment = DebugEnvironment()
  lazy var debugEnvironment: DebugEnvironment = {
    var id: Int = 0
    return .init { [baseEnvironment, processingQueue] string in
      processingQueue.async { [weak self] in
        for (index, component) in zip(0..., string.components(separatedBy: .newlines)) {
          var color: Color = .primary
          if index == 0 {
            color = .blue
          } else if component.starts(with: "+") {
            color = .green
          } else if component.starts(with: "-") {
            color = .red
          }
          self?.accumulator.messages.append(
            .init(
              id: id,
              content: component,
              color: color,
              isHeader: index == 0
            )
          )
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
          weight: message.isHeader ? .heavy : .semibold,
          design: .monospaced
        )
      )
      .foregroundColor(message.color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(
        Group {
          if message.isHeader {
            Divider()
              .frame(maxHeight: .infinity, alignment: .top)
          }
        }
      )
  }

  var consoleView: some View {
    List {
      ForEach(printer.messages) { message in
        if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
          row(message: message)
            .listRowSeparator(.hidden)
        } else {
          row(message: message)
        }
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
  @ViewBuilder
  public func debugUI(
    _ alignment: Alignment = .bottom,
    width: CGFloat? = nil,
    height: CGFloat? = 300,
    xOffset: CGFloat = 0,
    yOffset: CGFloat = 0,
    fontSize: CGFloat = 12,
    opacity: CGFloat = 0.9,
    hidden: Bool = false
  ) -> some View {
    #if DEBUG
    self.overlay(
      ReducerDebugView(
        fontSize: fontSize,
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
