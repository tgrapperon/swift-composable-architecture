import SwiftUI
extension View {
  func wrapInNavigationView() -> some View {
    NavigationView {
      self
    }
  }
}
