import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  @ObservedStore.Of<ViewState>.And<ViewAction>
  var store: Store<LoginState, LoginAction>

  struct ViewState: ViewStateProtocol {
    var alert: AlertState<LoginAction>?
    var email: String
    var isActivityIndicatorVisible: Bool
    var isFormDisabled: Bool
    var isLoginButtonDisabled: Bool
    var password: String
    var isTwoFactorActive: Bool

    init(state: LoginState) {
      self.alert = state.alert
      self.email = state.email
      self.isActivityIndicatorVisible = state.isLoginRequestInFlight
      self.isFormDisabled = state.isLoginRequestInFlight
      self.isLoginButtonDisabled = !state.isFormValid
      self.password = state.password
      self.isTwoFactorActive = state.twoFactor != nil
    }
  }

  enum ViewAction: ViewActionProtocol {
    static var embed: (Self) -> LoginAction {
      LoginAction.init
    }
    case alertDismissed
    case emailChanged(String)
    case loginButtonTapped
    case passwordChanged(String)
    case twoFactorDismissed
  }

  public init(store: Store<LoginState, LoginAction>) {
    self.store = store
  }

  public var body: some View {
    Form {
      Text(
        """
        To login use any email and "password" for the password. If your email contains the \
        characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
        use "1234" for the code.
        """
      )

      Section {
        TextField(
          "blob@pointfree.co",
          text: $store.binding(get: \.email, send: ViewAction.emailChanged)
        )
        .autocapitalization(.none)
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)

        SecureField(
          "••••••••",
          text: $store.binding(get: \.password, send: ViewAction.passwordChanged)
        )
      }

      NavigationLink(
        destination: IfLetStore(
          self.store.scope(state: \.twoFactor, action: LoginAction.twoFactor)
        ) {
          TwoFactorView(store: $0)
        },
        isActive: $store.binding(
          get: \.isTwoFactorActive,
          send: {
            // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
            //     if you disable a text field while it is focused. This hack will force all
            //     fields to unfocus before we send the action to the view store.
            // CF: https://stackoverflow.com/a/69653555
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
            return $0 ? .loginButtonTapped : .twoFactorDismissed
          }
        )
      ) {
        Text("Log in")
        if $store.isActivityIndicatorVisible {
          Spacer()
          ProgressView()
        }
      }
      .disabled($store.isLoginButtonDisabled)
    }
    .disabled($store.isFormDisabled)
    .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
    .navigationTitle("Login")
  }
}

extension LoginAction {
  init(action: LoginView.ViewAction) {
    switch action {
    case .alertDismissed:
      self = .alertDismissed
    case .twoFactorDismissed:
      self = .twoFactorDismissed
    case let .emailChanged(email):
      self = .emailChanged(email)
    case .loginButtonTapped:
      self = .loginButtonTapped
    case let .passwordChanged(password):
      self = .passwordChanged(password)
    }
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoginView(
        store: Store(
          initialState: LoginState(),
          reducer: loginReducer,
          environment: LoginEnvironment(
            authenticationClient: AuthenticationClient(
              login: { _ in
                Effect(value: AuthenticationResponse(token: "deadbeef", twoFactorRequired: false))
              },
              twoFactor: { _ in
                Effect(value: AuthenticationResponse(token: "deadbeef", twoFactorRequired: false))
              }
            ),
            mainQueue: .main
          )
        )
      )
    }
  }
}
