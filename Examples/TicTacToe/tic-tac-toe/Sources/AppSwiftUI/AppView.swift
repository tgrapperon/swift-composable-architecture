import AppCore
import ComposableArchitecture
import LoginSwiftUI
import NewGameSwiftUI
import SwiftUI

public struct AppView: View {
  let store: Store<AppState, AppAction>

  public init(store: Store<AppState, AppAction>) {
    self.store = store
  }

  public var body: some View {
    SwitchStoreBT(self.store) { state in
      switch state {
      case .login:
        CaseLet(state: /AppState.login, action: AppAction.login) { store in
          NavigationView {
            LoginView(store: store)
          }
          .navigationViewStyle(.stack)
        }
      case .newGame:
        CaseLet(state: /AppState.newGame, action: AppAction.newGame) { store in
          NavigationView {
            NewGameView(store: store)
          }
          .navigationViewStyle(.stack)
        }
      }
    }
  }
}
