
import SwiftUI
@available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension WithViewStore where Content: View {
  public func task(_ action: Action) -> some View {
    self.task {
      await viewStore.send(action).finish()
    }
  }
}
