import ComposableArchitecture
import SwiftUI

// MARK: - 5 - Leaf Domain
struct TerminalLeaf2: ReducerProtocol {
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
struct PassthroughDistalBranch2: ReducerProtocol {
  struct State {
    var terminalLeaf: TerminalLeaf2.State = .init(value: 0)
  }

  enum Action: Sendable {
    case terminalLeaf(TerminalLeaf2.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.terminalLeaf, action: /Action.terminalLeaf) {
      TerminalLeaf2()
    }
  }
}

// MARK: - 2 - Branch Domain
struct Branch2: ReducerProtocol {
  struct State {
    var value: String
    var distal: PassthroughDistalBranch2.State = .init()
  }

  enum Action: Sendable {
    case distal(PassthroughDistalBranch2.Action)
    case task
    case value(String)
  }

  @Dependency(\.branchValue) var dependencyValues

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.distal, action: /Action.distal) {
      PassthroughDistalBranch2()
    }
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
      }
    }
  }
}

// MARK: - 1 - Passthrough Domain
struct PassthroughProximalBranch2: ReducerProtocol {
  struct State {
    var branch: Branch2.State = .init(value: "")
  }

  enum Action: Sendable {
    case branch(Branch2.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.branch, action: /Action.branch) {
      Branch2()
    }
  }
}

// MARK: - 0 - Root Domain
struct RootDomain2: ReducerProtocol {
  struct State {
    var uuid: UUID
    var string: String
    var int: Int
    var proximal: PassthroughProximalBranch2.State = .init()
  }

  enum Action: Sendable {
    case proximal(PassthroughProximalBranch2.Action)
    case uuid(UUID)
    case string(String)
    case int(Int)
    case prime
  }

  @Dependency(\.branchValue) var branch
  @Dependency(\.terminalLeafValue) var terminalLeaf

  func updateDepedencencies(state: State) -> Effect<Action, Never> {
    .fireAndForget {
      await withTaskGroup(of: Void.self) {
        $0.addTask {
          await branch.send((state.string, state.int))
        }
        $0.addTask {
          await terminalLeaf.send(state.int)
        }
      }
    }
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.proximal, action: /Action.proximal) {
      PassthroughProximalBranch2()
    }

    Reduce { state, action in
      switch action {
      case .proximal:
        return .none
      case let .uuid(uuid):
        state.uuid = uuid
        return updateDepedencencies(state: state)
      case let .string(string):
        state.string = string
        return updateDepedencencies(state: state)
      case let .int(int):
        state.int = int
        return updateDepedencencies(state: state)
      case .prime:
        return updateDepedencencies(state: state)
      }
    }
  }
}

// MARK: Views

struct TerminalLeafView2: View {
  let store: StoreOf<TerminalLeaf2>
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

struct PassthroughDistalBranchView2: View {
  let store: StoreOf<PassthroughDistalBranch2>
  var body: some View {
    Section {
      Image(systemName: "arrow.down")
    } header: {
      Text("Passthrough domain")
    }
    TerminalLeafView2(
      store: store.scope(
        state: \.terminalLeaf, action: PassthroughDistalBranch2.Action.terminalLeaf
      ))
  }
}

struct BranchView2: View {
  let store: StoreOf<Branch2>
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
    PassthroughDistalBranchView2(
      store: store.scope(
        state: \.distal, action: Branch2.Action.distal
      )
    )
  }
}

struct PassthroughProximalBranchView2: View {
  let store: StoreOf<PassthroughProximalBranch2>
  var body: some View {
    Section {
      Image(systemName: "arrow.down")
    } header: {
      Text("Passthrough")
    }
    BranchView2(
      store: store.scope(
        state: \.branch, action: PassthroughProximalBranch2.Action.branch
      )
    )
  }
}

struct RootDomainView2: View {
  let store: StoreOf<RootDomain2>
  struct ViewState: Equatable {
    let uuid: UUID
    let string: String
    let int: Int
    init(state: RootDomain2.State) {
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
              text: viewStore.binding(get: \.string, send: RootDomain2.Action.string)
            )
          }
          Stepper(
            value: viewStore.binding(get: \.int, send: RootDomain2.Action.int)) {
            Text("Int value: \(viewStore.state.int)")
          }
        }
      } header: {
        Text("Root Domain")
      }
 
      PassthroughProximalBranchView2(
        store: store.scope(state: \.proximal, action: RootDomain2.Action.proximal)
      )
      .onAppear {
        ViewStore(store.stateless).send(.prime)
      }
    }
  }
}

struct RootDomainView2_Previews: PreviewProvider {
  static var previews: some View {
    RootDomainView2(
      store: .init(
        initialState: .init(
          uuid: UUID(),
          string: "abc",
          int: 123
        ), reducer: RootDomain2()
      ))
  }
}
