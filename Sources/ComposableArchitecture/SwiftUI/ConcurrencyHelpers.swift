
import SwiftUI
@available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension WithViewStore where Content: View {
  public func task(action: Action) -> some View {
    self.task {
      await viewStore.send(action).finish()
    }
  }
}

@available(macOS 12, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension View {
  func task<State, Action>(store: Store<State, Action>, action: Action) -> some View {
    self.task {
      await ViewStore(store.stateless).send(action).finish()
    }
  }
}
