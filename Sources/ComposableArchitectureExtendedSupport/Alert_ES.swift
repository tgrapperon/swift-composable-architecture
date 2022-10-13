import CustomDump
import SwiftUI
@_spi(ExtentedSupport) import ComposableArchitecture

extension LegacyView {
  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the alert is shown or dismissed.
  ///   - dismissal: An action to send when the alert is dismissed through non-user actions, such
  ///     as when an alert is automatically dismissed by the system. Use this action to `nil` out
  ///     the associated alert state.
  @ViewBuilder public func alert<Action>(
    _ store: Store<AlertState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      self.modifier(
        NewAlertModifier(
          viewStore: ViewStore(store, removeDuplicates: { $0?.id == $1?.id }),
          dismiss: dismiss
        )
      )
    } else {
      self.modifier(
        OldAlertModifier(
          viewStore: ViewStore(store, removeDuplicates: { $0?.id == $1?.id }),
          dismiss: dismiss
        )
      )
    }
  }
}

// NB: Workaround for iOS 14 runtime crashes during iOS 15 availability checks.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct NewAlertModifier<Action>: ViewModifier {
  @ObservedObject var viewStore: ViewStore<AlertState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    content.alert(
      (viewStore.state?.title).map { Text($0) } ?? Text(""),
      isPresented: viewStore.binding(send: dismiss).isPresent(),
      presenting: viewStore.state,
      actions: { $0.toSwiftUIActions(send: { viewStore.send($0) }) },
      message: { $0.message.map { Text($0) } }
    )
  }
}

private struct OldAlertModifier<Action>: ViewModifier {
  @ObservedObject var viewStore: ViewStore<AlertState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    content.alert(item: viewStore.binding(send: dismiss)) { state in
      state.toSwiftUIAlert(send: { viewStore.send($0) })
    }
  }
}

extension AlertState.Button {
  func toSwiftUIAction(send: @escaping (Action) -> Void) -> () -> Void {
    return {
      switch self.action?.type {
      case .none:
        return
      case let .some(.send(action)):
        send(action)
      case let .some(.animatedSend(action, animation: animation)):
        withAnimation(animation) { send(action) }
      }
    }
  }

  func toSwiftUIAlertButton(send: @escaping (Action) -> Void) -> SwiftUI.Alert.Button {
    let action = self.toSwiftUIAction(send: send)
    switch self.role {
    case .cancel:
      return .cancel(Text(label), action: action)
    case .destructive:
      return .destructive(Text(label), action: action)
    case .none:
      return .default(Text(label), action: action)
    }
  }

  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  func toSwiftUIButton(send: @escaping (Action) -> Void) -> some View {
    SwiftUI.Button(
      role: self.role?.toSwiftUI,
      action: self.toSwiftUIAction(send: send)
    ) {
      Text(self.label)
    }
  }
}

extension AlertState {
  @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
  @ViewBuilder
  fileprivate func toSwiftUIActions(send: @escaping (Action) -> Void) -> some View {
    ForEach(self.buttons.indices, id: \.self) {
      self.buttons[$0].toSwiftUIButton(send: send)
    }
  }

  fileprivate func toSwiftUIAlert(send: @escaping (Action) -> Void) -> SwiftUI.Alert {
    if self.buttons.count == 2 {
      return SwiftUI.Alert(
        title: Text(self.title),
        message: self.message.map { Text($0) },
        primaryButton: self.buttons[0].toSwiftUIAlertButton(send: send),
        secondaryButton: self.buttons[1].toSwiftUIAlertButton(send: send)
      )
    } else {
      return SwiftUI.Alert(
        title: Text(self.title),
        message: self.message.map { Text($0) },
        dismissButton: self.buttons.first?.toSwiftUIAlertButton(send: send)
      )
    }
  }
}

extension Binding {
  func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
    .init(
      get: { self.wrappedValue != nil },
      set: { isPresent, transaction in
        guard !isPresent else { return }
        self.transaction(transaction).wrappedValue = nil
      }
    )
  }
}
