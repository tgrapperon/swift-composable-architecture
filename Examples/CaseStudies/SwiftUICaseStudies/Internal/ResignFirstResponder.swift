import SwiftUI

extension Binding {
  /// SwiftUI will print errors to the console about "AttributeGraph: cycle detected" if you disable
  /// a text field while it is focused. This hack will force all fields to unfocus before we write
  /// to a binding that may disable the fields.
  ///
  /// See also: https://stackoverflow.com/a/69653555
  @MainActor
  func resignFirstResponder() -> Self {
    Self(
      get: { self.wrappedValue },
      set: { newValue, transaction in
        #if os(iOS)
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        #elseif os(macOS)
        NSApplication.shared.keyWindow?.makeFirstResponder(
          NSApplication.shared.keyWindow?.firstResponder?.nextResponder
        )
        #endif

        self.transaction(transaction).wrappedValue = newValue
      }
    )
  }
}
