import SwiftUI

// We reuse `CaseLet` `StoreObservableObject`, and `enumTag`
public struct SwitchStoreBT<State, Action, Content: View>: View {
  public let store: Store<State, Action>
  public let content: (State) -> Content

  public init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping (State) -> Content
  ) {
    self.store = store
    self.content = content
  }

  public var body: some View {
    WithViewStore(store, removeDuplicates: { enumTag($0) == enumTag($1) }) {
      content($0.state)
        .environmentObject(StoreObservableObject(store: self.store))
    }
  }
}
