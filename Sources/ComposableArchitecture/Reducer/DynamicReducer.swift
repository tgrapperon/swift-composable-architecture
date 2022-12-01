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

  public var new: Any? {
    self.delegate.newState(for: id)
  }

  public mutating func reset() {
    self.wrappedValue = delegate.initialState(for: id)
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
  init(id: AnyHashable, wrappedValue: Any) {
    self.wrappedValue = wrappedValue
    self.id = id
  }
  public init<Action>(id: AnyHashable, _ action: Action) {
    self.wrappedValue = action
    self.id = id
  }
  let id: AnyHashable
  public var wrappedValue: Any
}

extension DynamicAction: Equatable {
  public static func == (lhs: DynamicAction, rhs: DynamicAction) -> Bool {
    guard lhs.id == rhs.id else { return false }
    return (lhs.wrappedValue as? any Equatable)?.isEqual(other: rhs.wrappedValue) == true
  }
}

public struct DynamicReducer {
  @Dependency(\.dynamicDomainDelegate) var delegate
  public init() {}
}

public struct DynamicDomainDelegate: Equatable, DependencyKey, EnvironmentKey {
  final class Storage {
    static var shared = Storage()
    var domains: [AnyHashable: DynamicDomain] = [:]
  }

  public static var liveValue: DynamicDomainDelegate = .init()
  public static var testValue: DynamicDomainDelegate { liveValue }
  public static var defaultValue: DynamicDomainDelegate { liveValue }

  private let storage = Storage.shared
  var token: UInt = 0

  func reducer<ID: Hashable>(for id: ID) -> (any ReducerProtocol)? {
    storage.domains[id]?.reducer()
  }

  func initialState<ID: Hashable>(for id: ID) -> Any? {
    return storage.domains[id]?.initialState()
  }

  func newState<ID: Hashable>(for id: ID) -> Any? {
    return storage.domains[id]?.newState()
  }

  @MainActor
  func view(id: AnyHashable) -> ((Store<DynamicState, DynamicAction>) -> AnyView)? {
    storage.domains[id]?.view
  }

  mutating func registerDynamicDomain(_ domain: DynamicDomain) {
    if let existing = self.storage.domains[domain.id] {
      if "\(existing.fileID)" != "\(domain.fileID)" || existing.line != domain.line {
        let message = """
        Warning, registering a dynamic domain more than once with the id: "\(domain.id)":
          - \(existing.fileID):\(existing.line)
          - \(domain.fileID):\(domain.line)
        This operation is not supported.
        """
        print(message)
      }
    } else {
      self.storage.domains[domain.id] = domain
      self.token += 1
    }
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.token == rhs.token
  }
}

extension DependencyValues {
  public internal(set) var dynamicDomainDelegate: DynamicDomainDelegate {
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
    guard action.id == state.id else {
      // TODO: Warn?
      return .none
    }
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
  let id: AnyHashable
  let reducer: () -> any ReducerProtocol
  let initialState: () -> Any
  let newState: () -> Any
  let action: (Any) -> DynamicAction
  let view: (Store<DynamicState, DynamicAction>) -> AnyView
  let file: StaticString
  let fileID: StaticString
  let line: UInt
}

extension DynamicDomain {
  init<ID: Hashable, Reducer: ReducerProtocol, Content: View>(
    id: ID,
    reducer: @autoclosure @escaping () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    newState: (() -> Reducer.State)? = nil,
    view: @escaping (Store<Reducer.State, Reducer.Action>) -> Content,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.id = id
    self.reducer = reducer
    self.initialState = initialState
    self.newState = newState ?? initialState
    self.action = { .init(id: id, wrappedValue: $0) }
    self.view = { AnyView($0.cast(id: id).map(view)) }
    self.file = file
    self.fileID = fileID
    self.line = line
  }
}

extension TestStore {
  public func dynamicDomain<ID: Hashable, Reducer: ReducerProtocol, Content: View>(
    id: ID,
    reducer: @escaping @autoclosure () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    newState: (() -> Reducer.State)? = nil,
    @ViewBuilder view: @escaping (StoreOf<Reducer>) -> Content,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> TestStore {
    self.dependencies.dynamicDomainDelegate.registerDynamicDomain(
      .init(
        id: id,
        reducer: reducer(),
        initialState: initialState(),
        newState: newState,
        view: view,
        file: file,
        fileID: fileID,
        line: line
      )
    )
    return self
  }
  
  public func dynamicDomain<ID, Reducer: ReducerProtocol, Content: View>(
    id: ID.Type,
    reducer: @escaping @autoclosure () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    @ViewBuilder view: @escaping (StoreOf<Reducer>) -> Content,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> TestStore {
    return self.dynamicDomain(
      id: ObjectIdentifier(ID.self),
      reducer: reducer(),
      initialState: initialState(),
      view: view,
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

extension View {
  public func dynamicDomain<ID: Hashable, Reducer: ReducerProtocol, Content: View>(
    id: ID,
    reducer: @escaping @autoclosure () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    newState: (() -> Reducer.State)? = nil,
    @ViewBuilder view: @escaping (StoreOf<Reducer>) -> Content,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> some View {
    self.transformEnvironment(\.dynamicDomainDelegate) {
      $0.registerDynamicDomain(
        .init(
          id: id,
          reducer: reducer(),
          initialState: initialState(),
          newState: newState,
          view: view,
          file: file,
          fileID: fileID,
          line: line
        )
      )
    }
  }

  public func dynamicDomain<ID, Reducer: ReducerProtocol, Content: View>(
    id: ID.Type,
    reducer: @escaping @autoclosure () -> Reducer,
    initialState: @autoclosure @escaping () -> Reducer.State,
    @ViewBuilder view: @escaping (StoreOf<Reducer>) -> Content,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> some View {
    return self.dynamicDomain(
      id: ObjectIdentifier(ID.self),
      reducer: reducer(),
      initialState: initialState(),
      view: view,
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct DynamicDomainView<ID: Hashable>: View {
  let id: ID
  let store: Store<DynamicState, DynamicAction>

  let file: StaticString
  let fileID: StaticString
  let line: UInt

  var previewWidth: CGFloat?
  var previewHeight: CGFloat?

  @Environment(\.dynamicDomainDelegate) var delegate
  var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }

  public init(
    id: ID,
    store: Store<DynamicState, DynamicAction>,
    previewWidth: CGFloat? = nil,
    previewHeight: CGFloat? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.id = id
    self.store = store
    self.previewWidth = previewWidth
    self.previewHeight = previewHeight
    self.file = file
    self.fileID = fileID
    self.line = line
  }
  
  public init<T>(
    id: T.Type,
    store: Store<DynamicState, DynamicAction>,
    previewWidth: CGFloat? = nil,
    previewHeight: CGFloat? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  )
  where ID == ObjectIdentifier {
    self = .init(
      id: ObjectIdentifier(T.self),
      store: store,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
      file: file,
      fileID: fileID,
      line: line
    )
  }
  public var body: some View {
    if let view = delegate.view(id: id)?(store) {
      view
    } else if isPreview {
      VStack {
        Text(verbatim: "Dynamic View Placeholder")
          .font(.callout)
          .bold()
        Text(verbatim: "ID: \(id)")
          .font(.callout)
        Text(verbatim: ("\(fileID)" as NSString).lastPathComponent + ":\(line)")
          .font(.footnote)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .frame(width: previewWidth, height: previewHeight)
      .background(Color.gray.opacity(0.5))
      .border(Color.gray)
    } else {
      // Runtime warning?
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
        store: .dynamic(id: 44),
        previewHeight: 100
      )
      DynamicDomainView(
        id: 55,
        store: .dynamic(id: 55),
        previewHeight: 200
      )
    }
  }
}
