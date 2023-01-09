import AuthenticationClient
import ComposableArchitecture
import SwiftUI
import TwoFactorCore

public struct TwoFactorView: View {
  let store: StoreOf<TwoFactor>

  struct ViewState: ObservableState, Equatable {
    @Observe(\.alert) var alert
    @Bind(\.$code) var code
    @Observe(\.isTwoFactorRequestInFlight) var isActivityIndicatorVisible
    @Observe(\.isTwoFactorRequestInFlight) var isFormDisabled
    @Observe({ !$0.isFormValid }) var isSubmitButtonDisabled

    init(state: TwoFactor.State) {}
  }

  public init(store: StoreOf<TwoFactor>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      Form {
        Text(#"To confirm the second factor enter "1234" into the form."#)

        Section {
          TextField("1234", text: viewStore.$code)
            .keyboardType(.numberPad)
        }

        HStack {
          Button("Submit") {
            // NB: SwiftUI will print errors to the console about "AttributeGraph: cycle detected"
            //     if you disable a text field while it is focused. This hack will force all
            //     fields to unfocus before we send the action to the view store.
            // CF: https://stackoverflow.com/a/69653555
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
            viewStore.send(.submitButtonTapped)
          }
          .disabled(viewStore.isSubmitButtonDisabled)

          if viewStore.isActivityIndicatorVisible {
            Spacer()
            ProgressView()
          }
        }
      }
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
      .disabled(viewStore.isFormDisabled)
      .navigationTitle("Confirmation Code")
    }
  }
}

struct TwoFactorView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TwoFactorView(
        store: Store(
          initialState: TwoFactor.State(token: "deadbeef"),
          reducer: TwoFactor()
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
