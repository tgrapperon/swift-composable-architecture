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
  
  public var body: Content {
    content(scopedStore)
  }
  
  // TODO: compare store lifetime with the existing configuration
//  public var body: ModifiedContent<Content, _AppearanceActionModifier> {
//    content(scopedStore)
//      .onDisappear {
//        $scopedStore.onDisappear()
//      } as! ModifiedContent<Content, _AppearanceActionModifier>
//  }
  
  // Stores are not immediatly deinitialized when the view disappears. It seems to also be the case
  // with plain old properties, and thus with the current way it works, but this is need be checked
  // more thouroughly. It doesn't seem that @State lives longer than a bare property in a view that
  // disappeared.
}
