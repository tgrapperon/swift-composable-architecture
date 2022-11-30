import SwiftUI

@propertyWrapper
public struct DynamicState {
  @Dependency(\.dynamicDomainDelegate) var delegate
  public init(id: AnyHashable) {
    self.id = id
    self.wrappedValue = self.delegate.initialState(for: id)
  }
  public init(id: Any.Type) {
    self = .init(id: ObjectIdentifier(id))
  }

  let id: AnyHashable
  public var wrappedValue: Any?

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  @discardableResult
  public mutating func modify<T, Result>(as: T.Type, perform: (inout T) -> Result) -> Result? {
    guard var wrappedValue = wrappedValue as? T else { return nil }
    defer { self.wrappedValue = wrappedValue }
    return perform(&wrappedValue)
  }
}

extension DynamicState: Equatable {
  public static func == (lhs: DynamicState, rhs: DynamicState) -> Bool {
    guard lhs.id == rhs.id else { return false }
    guard let lhs = lhs.wrappedValue, let rhs = rhs.wrappedValue else {
      return (lhs.wrappedValue == nil) && (lhs.wrappedValue == nil)
    }
    return (lhs as? any Equatable)?.isEqual(other: rhs) == true
  }
}

extension Equatable {
  fileprivate func isEqual(other: Any) -> Bool {
    self == other as? Self
  }
}

//@propertyWrapper
public struct DynamicAction {
  public init(id: AnyHashable, wrappedValue: Any) {
    self.wrappedValue = wrappedValue
    self.id = id
  }
  let id: AnyHashable
  public var wrappedValue: Any
}

extension DynamicAction: Equatable {
  public static func == (lhs: DynamicAction, rhs: DynamicAction) -> Bool {
    lhs.id == rhs.id
  }
}

public struct DynamicReducer {
  @Dependency(\.dynamicDomainDelegate) var delegate
  public init() {}
}

public final class DynamicDomainDelegate: DependencyKey, EnvironmentKey {
  static let shared = DynamicDomainDelegate()
  public static var liveValue: DynamicDomainDelegate { shared }
  public static var defaultValue: DynamicDomainDelegate { shared }

  private var domains: [AnyHashable: DynamicDomain] = [:]

  func reducer<ID: Hashable>(for id: ID) -> (any ReducerProtocol)? {
    domains[id]?.reducer()
  }

  func initialState<ID: Hashable>(for id: ID) -> Any? {
    return domains[id]?.initialState()
  }

  @MainActor
  func view(id: AnyHashable) -> ((Store<DynamicState, DynamicAction>) -> AnyView)? {
    domains[id]?.view
  }

  func registerDynamicDomain(_ domain: DynamicDomain) {
    self.domains[domain.id] = domain
  }

}

extension DependencyValues {
  public var dynamicDomainDelegate: DynamicDomainDelegate {
    get { self[DynamicDomainDelegate.self] }
    set { self[DynamicDomainDelegate.self] = newValue }
  }
}

extension EnvironmentValues {
  var dynamicDomainDelegate: DynamicDomainDelegate {
    get { self[DynamicDomainDelegate.self] }
    set { self[DynamicDomainDelegate.self] = newValue }
  }
}

extension ReducerProtocol {
  func reduceDynamic(into state: inout DynamicState, action: DynamicAction) -> EffectTask<
    DynamicAction
  > {
    guard
      let _action = action.wrappedValue as? Action,
      var _state = state.wrappedValue as? State
    else {
      return EffectTask<DynamicAction>.none
    }
    defer { state.wrappedValue = _state }
    return self.reduce(into: &_state, action: _action)
      .map { DynamicAction.init(id: action.id, wrappedValue: $0) }
  }
}

extension DynamicReducer: ReducerProtocol {
  public func reduce(into state: inout DynamicState, action: DynamicAction) -> EffectTask<
    DynamicAction
  > {
    guard let reducer = delegate.reducer(for: state.id) else {
      // TODO: Warn
      return .none
    }
    return reducer.reduceDynamic(into: &state, action: action)
  }
}

extension Store where State == DynamicState, Action == DynamicAction {
  func cast<S, A>(id: AnyHashable) -> Store<S, A>? {
    guard
      let value =
        ViewStore(self, observe: { $0 }, removeDuplicates: { _, _ in false }).state.wrappedValue
        as? S
    else { return nil }
    return self.scope {
      $0.wrappedValue as? S ?? value
    } action: {
      .init(id: id, wrappedValue: $0)
    }
  }
}

struct DynamicDomain {
  var id: AnyHashable
  var reducer: () -> any ReducerProtocol
  var initialState: () -> Any
  var action: (Any) -> DynamicAction
  var view: (Store<DynamicState, DynamicAction>) -> AnyView
}

extension DynamicDomain {
  init<ID: Hashable, Reducer: ReducerProtocol, Content: View>(
    id: ID,
    reducer: @autoclosure @escaping () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    view: @escaping (Store<Reducer.State, Reducer.Action>) -> Content
  ) {
    self.id = id
    self.reducer = reducer
    self.initialState = initialState
    self.action = { .init(id: id, wrappedValue: $0) }
    self.view = { AnyView($0.cast(id: id).map(view)) }
  }
}

extension View {
  public func registerDynamicDomain<ID: Hashable, Reducer: ReducerProtocol, Content: View>(
    id: ID,
    reducer: @escaping @autoclosure () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    @ViewBuilder view: @escaping (StoreOf<Reducer>) -> Content
  ) -> some View {
    self.transformEnvironment(\.dynamicDomainDelegate) {
      $0.registerDynamicDomain(
        .init(
          id: id,
          reducer: reducer(),
          initialState: initialState(),
          view: view
        )
      )
    }
  }

  public func registerDynamicDomain<ID, Reducer: ReducerProtocol, Content: View>(
    id: ID.Type,
    reducer: @escaping @autoclosure () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    @ViewBuilder view: @escaping (StoreOf<Reducer>) -> Content
  ) -> some View {
    return self.registerDynamicDomain(
      id: ObjectIdentifier(ID.self),
      reducer: reducer(),
      initialState: initialState(),
      view: view
    )
  }
}

public struct DynamicDomainView<ID: Hashable>: View {
  let id: ID
  let store: Store<DynamicState, DynamicAction>

  let file: StaticString
  let fileID: StaticString
  let line: UInt

  @Environment(\.dynamicDomainDelegate) var delegate
  var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }
  public init(
    id: ID,
    store: Store<DynamicState, DynamicAction>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.id = id
    self.store = store
    self.file = file
    self.fileID = fileID
    self.line = line
  }
  public init<T>(
    id: T.Type,
    store: Store<DynamicState, DynamicAction>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  )
  where ID == ObjectIdentifier {
    self.id = ObjectIdentifier(T.self)
    self.store = store
    self.file = file
    self.fileID = fileID
    self.line = line
  }
  public var body: some View {
    if let view = delegate.view(id: id)?(store) {
      view
    } else if isPreview {
      Text("Preview warning")
    } else {
      Text("Runtime warning")
    }
  }
}

extension Store {
  public static func dynamic<ID: Hashable>(id: ID) -> Store<DynamicState, DynamicAction> {
    .init(initialState: DynamicState(id: id), reducer: DynamicReducer())
  }
}

struct DynamicDomainView_Previews: PreviewProvider {

  static var previews: some View {
    VStack {
      DynamicDomainView(
        id: 44,
        store: .dynamic(id: 44)
      )
    }
    .registerDynamicDomain(id: 44, reducer: EmptyReducer<Void, Void>(), initialState: ()) { store in
      Text("Dynamic")
    }
  }
}
