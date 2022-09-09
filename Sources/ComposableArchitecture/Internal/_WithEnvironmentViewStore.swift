import SwiftUI

public struct _WithEnvironmentViewStore<State, Action, Content>{
  let content: (ViewStore<State, Action>) -> Content
  @EnvironmentObject var viewStore: ViewStore<State, Action>
}

extension _WithEnvironmentViewStore: View where Content: View {
  init(@ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content) {
    self.content = content
  }
  public var body: some View {
    content(viewStore)
  }
}
