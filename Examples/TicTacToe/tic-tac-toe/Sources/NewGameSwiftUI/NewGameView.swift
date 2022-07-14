import ComposableArchitecture
import GameCore
import GameSwiftUI
import NewGameCore
import SwiftUI

public struct NewGameView: View {
  @ObservedStore.Of<ViewState>.And<ViewAction>
  var store: Store<NewGameState, NewGameAction>

  struct ViewState: ViewStateProtocol {
    var isGameActive: Bool
    var isLetsPlayButtonDisabled: Bool
    var oPlayerName: String
    var xPlayerName: String

    init(state: NewGameState) {
      self.isGameActive = state.game != nil
      self.isLetsPlayButtonDisabled = state.oPlayerName.isEmpty || state.xPlayerName.isEmpty
      self.oPlayerName = state.oPlayerName
      self.xPlayerName = state.xPlayerName
    }
  }

  enum ViewAction: ViewActionProtocol {
    case gameDismissed
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
    
    static var embed: (Self) -> NewGameAction {
      NewGameAction.init(action:)
    }
  }

  public init(store: Store<NewGameState, NewGameAction>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Section {
        TextField(
          "Blob Sr.",
          text: $store.binding(get: \.xPlayerName, send: ViewAction.xPlayerNameChanged)
        )
        .autocapitalization(.words)
        .disableAutocorrection(true)
        .textContentType(.name)
      } header: {
        Text("X Player Name")
      }

      Section {
        TextField(
          "Blob Jr.",
          text: $store.binding(get: \.oPlayerName, send: ViewAction.oPlayerNameChanged)
        )
        .autocapitalization(.words)
        .disableAutocorrection(true)
        .textContentType(.name)
      } header: {
        Text("O Player Name")
      }

      NavigationLink(
        destination: IfLetStore(self.store.scope(state: \.game, action: NewGameAction.game)) {
          GameView(store: $0)
        },
        isActive: $store.binding(
          get: \.isGameActive,
          send: { $0 ? .letsPlayButtonTapped : .gameDismissed }
        )
      ) {
        Text("Let's play!")
      }
      .disabled($store.isLetsPlayButtonDisabled)
      .navigationTitle("New Game")
      .navigationBarItems(trailing: Button("Logout") { $store.send(.logoutButtonTapped) })
    }
  }
}

extension NewGameAction {
  init(action: NewGameView.ViewAction) {
    switch action {
    case .gameDismissed:
      self = .gameDismissed
    case .letsPlayButtonTapped:
      self = .letsPlayButtonTapped
    case .logoutButtonTapped:
      self = .logoutButtonTapped
    case let .oPlayerNameChanged(name):
      self = .oPlayerNameChanged(name)
    case let .xPlayerNameChanged(name):
      self = .xPlayerNameChanged(name)
    }
  }
}

struct NewGame_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NewGameView(
        store: Store(
          initialState: NewGameState(),
          reducer: newGameReducer,
          environment: NewGameEnvironment()
        )
      )
    }
  }
}
