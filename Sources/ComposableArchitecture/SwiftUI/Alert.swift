import SwiftUI

extension View {
  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the alert is shown or dismissed.
  ///   - dismissal: An action to send when the alert is dismissed through non-user actions, such
  ///     as when an alert is automatically dismissed by the system. Use this action to `nil` out
  ///     the associated alert state.
  @ViewBuilder public func alert<Action>(
    _ store: @escaping @autoclosure () -> Store<AlertState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      self.modifier(
        NewAlertModifier(store: .init(initialValue: store()), dismiss: dismiss)
      )
    } else {
      self.modifier(
        OldAlertModifier(store: .init(initialValue: store()), dismiss: dismiss))
    }
  }
}

// NB: Workaround for iOS 14 runtime crashes during iOS 15 availability checks.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct NewAlertModifier<Action>: ViewModifier {
  @State var store: _Lazy<Store<AlertState<Action>?, Action>>
  let dismiss: Action

  func body(content: Content) -> some View {
    WithViewStore(store.wrappedValue, observe: { $0 }, removeDuplicates: { $0?.id == $1?.id }) { viewStore in
      content.alert(
        (viewStore.state?.title).map { Text($0) } ?? Text(""),
        isPresented: viewStore.binding(send: dismiss).isPresent(),
        presenting: viewStore.state,
        actions: {
          ForEach($0.buttons) {
            Button($0) { viewStore.send($0) }
          }
        },
        message: { $0.message.map { Text($0) } }
      )
    }
  }
}

private struct OldAlertModifier<Action>: ViewModifier {
  @State var store: _Lazy<Store<AlertState<Action>?, Action>>
  let dismiss: Action

  func body(content: Content) -> some View {
    WithViewStore(store.wrappedValue, observe: { $0 }, removeDuplicates: { $0?.id == $1?.id }) { viewStore in
      content.alert(item: viewStore.binding(send: dismiss)) { state in
        Alert(state) { viewStore.send($0) }
      }
    }
  }
}
