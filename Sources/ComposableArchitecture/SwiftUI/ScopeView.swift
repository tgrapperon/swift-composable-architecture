import SwiftUI

public struct ScopeView<ParentState, ParentAction, ChildState, ChildAction, Content: View>: View {
  let store: Store<ParentState, ParentAction>
  @_LazyState var scopedStore: Store<ChildState, ChildAction>
  let content: (Store<ChildState, ChildAction>) -> Content
  public init(
    store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> ChildState,
    action: @escaping (ChildAction) -> ParentAction,
    @ViewBuilder content: @escaping (Store<ChildState, ChildAction>) -> Content
  ) {
    self.store = store
    self._scopedStore = .init(wrappedValue: store.scope(state: state, action: action))
    self.content = content
  }

  public var body: ModifiedContent<Content, _AppearanceActionModifier> {
    content(scopedStore)
      .onDisappear {
        $scopedStore.onDisappear()
      } as! ModifiedContent<Content, _AppearanceActionModifier>
  }
}
