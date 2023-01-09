import AuthenticationClient
import ComposableArchitecture
import LoginCore
import SwiftUI
import TwoFactorCore
import TwoFactorSwiftUI

public struct LoginView: View {
  let store: StoreOf<Login>

  struct ViewState: ObservableState, Equatable {
    @Observe(\.alert) var alert: AlertState<Login.Action>?
    @Bind(\.$email) var email: String
    @Observe(\.isLoginRequestInFlight) var isActivityIndicatorVisible: Bool
    @Observe(\.isLoginRequestInFlight) var isFormDisabled: Bool // With or without type
    var isLoginButtonDisabled: Bool // Property wrappers can be mixed with bare properties
    @Bind(\.$password) var password: String
    @Observe({ $0.twoFactor != nil }) var isTwoFactorActive: Bool

    init(state: Login.State) {
      self.isLoginButtonDisabled = !state.isFormValid
    }
  }

  public init(store: StoreOf<Login>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      Form {
        Text(
          """
          To login use any email and "password" for the password. If your email contains the \
          characters "2fa" you will be taken to a two-factor flow, and on that screen you can \
          use "1234" for the code.
          """
        )

        Section {
          TextField("blob@pointfree.co", text: viewStore.$email)
            .autocapitalization(.none)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)

          SecureField("••••••••", text: viewStore.$password)
        }

        NavigationLink(
          destination: IfLetStore(
            self.store.scope(state: \.twoFactor, action: Login.Action.twoFactor)
          ) {
            TwoFactorView(store: $0)
          },
          isActive: viewStore.binding(
            get: \.isTwoFactorActive,
            send: {
              // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
              //     if you disable a text field while it is focused. This hack will force all
              //     fields to unfocus before we send the action to the view store.
              // CF: https://stackoverflow.com/a/69653555
              _ = UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
              )
              return $0 ? .loginButtonTapped : .twoFactorDismissed
            }
          )
        ) {
          Text("Log in")
          if viewStore.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
        .disabled(viewStore.isLoginButtonDisabled)
      }
      .disabled(viewStore.isFormDisabled)
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
    }
    .navigationTitle("Login")
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoginView(
        store: Store(
          initialState: Login.State(),
          reducer: Login()
            .dependency(\.authenticationClient.login) { _ in
              AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
            }
            .dependency(\.authenticationClient.twoFactor) { _ in
              AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
            }
        )
      )
    }
  }
}
