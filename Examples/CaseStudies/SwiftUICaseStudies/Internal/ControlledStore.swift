import ComposableArchitecture
import SwiftUI

public enum ControlledStore {}

extension ControlledStore {
  public enum Command: Equatable {
    case run
    case pause
  }
}

public struct Start { public init() {} }
public struct Stop { public init() {} }
public struct Loop { public init() {} }

public struct Send<Action> {
  var action: Action
  var delay: TimeInterval?
  var animation: Animation?
  public init(
    _ action: Action, after delay: TimeInterval? = nil, animation: Animation? = nil
  ) {
    self.action = action
    self.delay = delay
    self.animation = animation
  }
}

public struct Wait {
  let duration: TimeInterval
  public init(seconds: TimeInterval = 0) {
    self.duration = seconds
  }
}

public struct WithControlledStore<State, Action, Content: View>: View {
  let content: Content
  let store: Store<State, Action>
  let actions: [ControlledStore.Action]
  let command: (() -> ControlledStore.Command?)?
  @StateObject var storeController = StoreController()
  public init(
    _ store: Store<State, Action>,
    @ControlledStore.ActionsBuilder<Action> actions: () -> [ControlledStore.Action],
    controllerState command: (() -> ControlledStore.Command?)? = nil,
    @ViewBuilder content: (Store<State, Action>) -> Content
  ) {
    self.store = store
    self.command = command
    self.content = content(store)
    self.actions = actions()

  }
  public var body: some View {
    content
      .task {
        storeController.register(store: store, actions: actions)
        if let command = command {
          storeController.send(command())
        } else if case .command(.run) = actions.first {
          storeController.send(.run)
        }
      }
      .onChange(of: command?(), perform: storeController.send)
  }
}

extension WithControlledStore {
  final class StoreController: ObservableObject {
    var controllerStore: Store<Void, ControlledStore.Action>?
    var controllerViewStore: ViewStore<Void, ControlledStore.Action>?
    var store: Any?
    init() {}
    func register<State>(store: Store<State, Action>, actions: [ControlledStore.Action]) {
      guard controllerStore == nil else { return }
      self.store = store
      let viewStore = ViewStore(store.stateless)
      var actionIndex = actions.startIndex
      let id = ObjectIdentifier(self)
      func nextAction() -> ControlledStore.Action? {
        actionIndex < actions.count ? actions[actionIndex] : nil
      }
      var actionIsInFlight: Bool = false
      let reducer = Reducer<Void, ControlledStore.Action, Void> { _, action, _ in

        switch action {
        case let .send(action, delay, animation):
          actionIndex += 1
          actionIsInFlight = true
          return .merge(
            .fireAndForget { viewStore.send(action as! Action, animation: animation) },
            Effect(value: nextAction() ?? .end)
          ).deferred(
            for: .seconds(delay ?? 0),
            scheduler: DispatchQueue.main.eraseToAnyScheduler()
          )
          .cancellable(id: id, cancelInFlight: true)
        case .command(.run):
          var action = nextAction()
          while case .command(.run) = action, action != nil {
            actionIndex += 1
            action = nextAction()
          }
          return Effect(value: action ?? .end)
        case .command(.pause):
          if actionIsInFlight, actionIndex > 0 {
            actionIndex -= 1
          }
          actionIsInFlight = false
          return .cancel(id: id)
        case .end:
          actionIsInFlight = false
          return .cancel(id: id)
        case .loop:
          actionIndex = 0
          actionIsInFlight = false
          return Effect(value: nextAction() ?? .end)
        case let .next(delay):
          actionIndex += 1
          actionIsInFlight = true
          return Effect(value: .command(.run))
            .deferred(
              for: .seconds(delay ?? 0),
              scheduler: DispatchQueue.main.eraseToAnyScheduler()
            )
            .cancellable(id: id, cancelInFlight: true)
        }
      }
      self.controllerStore = Store(initialState: (), reducer: reducer, environment: ())
      self.controllerViewStore = ViewStore(controllerStore!)
    }

    func send(_ command: ControlledStore.Command?) {
      guard let command = command else { return }
      controllerViewStore?.send(.command(command))
    }
  }
}

extension ControlledStore {
  public enum Action {
    case send(Any, after: TimeInterval? = 0, animation: Animation? = nil)
    case command(Command)
    case end
    case loop
    case next(after: TimeInterval? = 0)
  }
}

extension ControlledStore {
  @resultBuilder
  public enum ActionsBuilder<Action> {

    public static func buildBlock(_ components: [ControlledStore.Action]...) -> [ControlledStore
      .Action]
    {
      components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: ()) -> [ControlledStore.Action] {
      []
    }

    public static func buildExpression(_ expression: Start) -> [ControlledStore.Action] {
      [.command(.run)]
    }

    public static func buildExpression(_ expression: Stop) -> [ControlledStore.Action] {
      [.command(.pause)]
    }

    public static func buildExpression(_ expression: Loop) -> [ControlledStore.Action] {
      [.loop]
    }

    public static func buildExpression(_ expression: Send<Action>) -> [ControlledStore.Action] {
      [.send(expression.action, after: expression.delay, animation: expression.animation)]
    }

    public static func buildExpression(_ expression: Wait) -> [ControlledStore.Action] {
      [.next(after: expression.duration)]
    }

    public static func buildExpression(_ expression: Action) -> [ControlledStore.Action] {
      [.send(expression)]
    }

    public static func buildOptional(_ component: [ControlledStore.Action]?) -> [ControlledStore
      .Action]
    {
      component ?? []
    }

    public static func buildEither(first component: [ControlledStore.Action]) -> [ControlledStore
      .Action]
    {
      return component
    }

    public static func buildEither(second component: [ControlledStore.Action]) -> [ControlledStore
      .Action]
    {
      return component
    }

    public static func buildArray(_ components: [[ControlledStore.Action]]) -> [ControlledStore
      .Action]
    {
      components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [ControlledStore.Action])
      -> [ControlledStore.Action]
    {
      component
    }
  }
}
