import ComposableArchitecture
import SwiftUI

// MARK: - 5 - Leaf Domain
enum TerminalLeafValueKey: LiveDependencyKey {
  static var testValue: AsyncSharedStream<Int> = .init(
    shouldEmitValueIfPossibleWhenIterationBegins: true)
  static var liveValue: AsyncSharedStream<Int> = .init(
    shouldEmitValueIfPossibleWhenIterationBegins: true)
}

extension DependencyValues {
  var terminalLeafValue: AsyncSharedStream<Int> {
    get { self[TerminalLeafValueKey.self] }
    set { self[TerminalLeafValueKey.self] = newValue }
  }
}

struct TerminalLeaf: ReducerProtocol {
  struct State: Equatable {
    var value: Int
  }

  enum Action: Sendable {
    case task
    case value(Int)
  }

  @Dependency(\.terminalLeafValue) var dependencyValues

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { send in
          for await value in dependencyValues {
            await send(.value(value))
          }
        }
      case let .value(value):
        state.value = value
        return .none
      }
    }
  }
}

// MARK: - 4 - Passthrough Domain
struct PassthroughDistalBranch: ReducerProtocol {
  struct State {
    var terminalLeaf: TerminalLeaf.State = .init(value: 0)
  }

  enum Action: Sendable {
    case terminalLeaf(TerminalLeaf.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.terminalLeaf, action: /Action.terminalLeaf) {
      TerminalLeaf()
    }
  }
}

// MARK: - 2 - Branch Domain
enum BranchValueKey: LiveDependencyKey {
  static var testValue: AsyncSharedStream<(String, Int)> = .init(
    shouldEmitValueIfPossibleWhenIterationBegins: true)
  static var liveValue: AsyncSharedStream<(String, Int)> = .init(
    shouldEmitValueIfPossibleWhenIterationBegins: true)
}
extension DependencyValues {
  var branchValue: AsyncSharedStream<(String, Int)> {
    get { self[BranchValueKey.self] }
    set { self[BranchValueKey.self] = newValue }
  }
}

struct Branch: ReducerProtocol {
  struct State {
    var value: String
    var distal: PassthroughDistalBranch.State = .init()
  }

  enum Action: Sendable {
    case distal(PassthroughDistalBranch.Action)
    case task
    case value(String)
    case prime
  }

  @Dependency(\.branchValue) var dependencyValues

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.distal, action: /Action.distal) {
      PassthroughDistalBranch()
    }
    .bindStreamDependency(\.branchValue, to: \.terminalLeafValue, transform: \.1)

    Reduce { state, action in
      switch action {
      case .distal:
        return .none
      case .task:
        return .run { send in
          for await value in dependencyValues {
            await send(.value(value.0))
          }
        }
      case let .value(value):
        state.value = value
        return .none
      case .prime:
        return .none
      }
    }
  }
}

// MARK: - 1 - Passthrough Domain
struct PassthroughProximalBranch: ReducerProtocol {
  struct State {
    var branch: Branch.State = .init(value: "")
  }

  enum Action: Sendable {
    case branch(Branch.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.branch, action: /Action.branch) {
      Branch()
    }
  }
}

// MARK: - 0 - Root Domain
enum RootValueKey: LiveDependencyKey {
  static var testValue: AsyncSharedStream<(UUID, String, Int)> = .init(
    shouldEmitValueIfPossibleWhenIterationBegins: true)
  static var liveValue: AsyncSharedStream<(UUID, String, Int)> = .init(
    shouldEmitValueIfPossibleWhenIterationBegins: true)
}

extension DependencyValues {
  var rootDomainValue: AsyncSharedStream<(UUID, String, Int)> {
    get { self[RootValueKey.self] }
    set { self[RootValueKey.self] = newValue }
  }
}

struct RootDomain: ReducerProtocol {
  struct State {
    var uuid: UUID
    var string: String
    var int: Int
    var proximal: PassthroughProximalBranch.State = .init()
  }

  enum Action: Sendable {
    case proximal(PassthroughProximalBranch.Action)
    case uuid(UUID)
    case string(String)
    case int(Int)
    case prime
  }

  @Dependency(\.rootDomainValue) var dependencyValues

  func updateDepedencency(state: State) async {
    await dependencyValues.send((state.uuid, state.string, state.int))
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.proximal, action: /Action.proximal) {
      PassthroughProximalBranch()
    }
    .bindStreamDependency(\.rootDomainValue, to: \.branchValue) {
      ($0.1, $0.2)
    }

    Reduce { state, action in
      switch action {
      case .proximal:
        return .none
      case let .uuid(uuid):
        state.uuid = uuid
        return .fireAndForget { [state] in await updateDepedencency(state: state) }
      case let .string(string):
        state.string = string
        return .fireAndForget { [state] in await updateDepedencency(state: state) }
      case let .int(int):
        state.int = int
        return .fireAndForget { [state] in await updateDepedencency(state: state) }
      case .prime:
        return .fireAndForget { [state] in await updateDepedencency(state: state) }
      }
    }
  }
}

// MARK: Views

struct TerminalLeafView: View {
  let store: StoreOf<TerminalLeaf>
  var body: some View {
    Section {
      WithViewStore(store) { viewStore in
        Text("Int: \(viewStore.value)")
          .task {
            await viewStore.send(.task).finish()
          }
      }
    } header: {
      Text("Leaf domain")
    }
  }
}

struct PassthroughDistalBranchView: View {
  let store: StoreOf<PassthroughDistalBranch>
  var body: some View {
    Section {
      Image(systemName: "arrow.down")
    } header: {
      Text("Passthrough domain")
    }
    TerminalLeafView(
      store: store.scope(
        state: \.terminalLeaf, action: PassthroughDistalBranch.Action.terminalLeaf
      ))
  }
}

struct BranchView: View {
  let store: StoreOf<Branch>
  var body: some View {
    Section {
      WithViewStore(store.scope(state: \.value)) { viewStore in
        Text("String: \(viewStore.state)")
          .task {
            await viewStore.send(.task).finish()
          }
      }
    } header: {
      Text("Branch domain")
    }
    PassthroughDistalBranchView(
      store: store.scope(
        state: \.distal, action: Branch.Action.distal
      )
    )
    .onAppear {
      ViewStore(store.stateless).send(.prime)
    }
  }
}

struct PassthroughProximalBranchView: View {
  let store: StoreOf<PassthroughProximalBranch>
  var body: some View {
    Section {
      Image(systemName: "arrow.down")
    } header: {
      Text("Passthrough")
    }
    BranchView(
      store: store.scope(
        state: \.branch, action: PassthroughProximalBranch.Action.branch
      )
    )
  }
}

struct RootDomainView: View {
  let store: StoreOf<RootDomain>
  struct ViewState: Equatable {
    let uuid: UUID
    let string: String
    let int: Int
    init(state: RootDomain.State) {
      self.uuid = state.uuid
      self.string = state.string
      self.int = state.int
    }
  }

  var body: some View {
    Form {
      Section {
        WithViewStore(store.scope(state: ViewState.init)) { viewStore in
          HStack(spacing: 0) {
            Text("String value: ")
            TextField(
              "Text",
              text: viewStore.binding(get: \.string, send: RootDomain.Action.string)
            )
          }
          Stepper(
            value: viewStore.binding(get: \.int, send: RootDomain.Action.int)) {
            Text("Int value: \(viewStore.state.int)")
          }
        }
      } header: {
        Text("Root Domain")
      }
 
      PassthroughProximalBranchView(
        store: store.scope(state: \.proximal, action: RootDomain.Action.proximal)
      )
      .onAppear {
        ViewStore(store.stateless).send(.prime)
      }
    }
  }
}

struct RootDomainView_Previews: PreviewProvider {
  static var previews: some View {
    RootDomainView(
      store: .init(
        initialState: .init(
          uuid: UUID(),
          string: "abc",
          int: 123
        ), reducer: RootDomain()
      ))
  }
}
