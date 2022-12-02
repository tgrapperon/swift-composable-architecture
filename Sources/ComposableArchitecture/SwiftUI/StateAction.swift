import Dependencies
import SwiftUI
/// A property wrapper type that can designate properties of an app state that can be expressed as
/// signals in SwiftUI views.
@propertyWrapper
public struct StateAction<Action> {
  struct ProjectedAction: Equatable {
    let action: Action
    let token: UUID
    // Note: Because this type is only used internally and on the UI side, using
    // `@Dependency(\.uuid) instead of `UUID.init` doesn't really improves testability and
    // furthermore forces the user to provide some `\.uuid` implementation when testing values with
    // `@StateAction`.
    init(_ action: Action, token: UUID = UUID()) {
      self.action = action
      self.token = token
    }
    static func == (lhs: ProjectedAction, rhs: ProjectedAction) -> Bool {
      lhs.token == rhs.token
    }
  }

  var projectedAction: ProjectedAction?
  var _wrappedValue: Action?

  public var wrappedValue: Action? {
    get { _wrappedValue }
    set {
      _wrappedValue = newValue
      if let newValue = newValue {
        projectedAction = ProjectedAction(newValue)
      } else {
        projectedAction = nil
      }
    }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
  
  public init(wrappedValue: Action? = nil) {
    self.wrappedValue = wrappedValue
  }
}

extension StateAction: Sendable where Action: Sendable {}
extension StateAction: Equatable where Action: Equatable {
  public static func == (lhs: StateAction<Action>, rhs: StateAction<Action>) -> Bool {
    lhs._wrappedValue == rhs._wrappedValue
  }
}

extension StateAction: Hashable where Action: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_wrappedValue)
  }
}

extension StateAction: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(
      self,
      children: [
        "action": self._wrappedValue as Any
      ],
      displayStyle: .enum
    )
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
extension View {
  /// A view modifier that performs the provided closure when a `StateAction` is assigned to the
  /// store's state by the reducer.
  ///
  /// Assigning the same value that was assigned on a previous reducer run produces a new signal.
  /// However, only the last signal assigned in a reducer's run is effectively expressed.
  ///
  /// - Parameters:
  ///   - store: the ``Store`` to observe.
  ///   - stateAction: a function from the store's state to a `StateAction` value, typically a
  ///   `KeyPath` from `State` to the `projectedValue` hosting the `StateAction`.
  ///   - perform: some action to perform when a new value is assigned to the `StateAction`.
  public func onStateAction<StoreState, StoreAction, Action>(
    store: Store<StoreState, StoreAction>,
    _ stateAction: @escaping (StoreState) -> StateAction<Action>,
    perform: @escaping (Action) -> Void
  ) -> some View {
    self.modifier(StateActionModifier(store: store, stateAction: stateAction, perform: perform))
  }
}

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
struct StateActionModifier<StoreState, Action>: ViewModifier {
  let perform: (Action) -> Void
  @StateObject var viewStore: ViewStore<StateAction<Action>.ProjectedAction?, Never>
  init<StoreAction>(
    store: Store<StoreState, StoreAction>,
    stateAction: @escaping (StoreState) -> StateAction<Action>,
    perform: @escaping (Action) -> Void
  ) {
    self._viewStore = StateObject(
      wrappedValue: ViewStore(store.scope(state: { stateAction($0).projectedAction }).actionless)
    )
    self.perform = perform
  }

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard let action = viewStore.state?.action else { return }
        perform(action)
      }
      .onChange(of: viewStore.state) { projectedAction in
        guard let projectedAction = projectedAction else { return }
        perform(projectedAction.action)
      }
  }
}
