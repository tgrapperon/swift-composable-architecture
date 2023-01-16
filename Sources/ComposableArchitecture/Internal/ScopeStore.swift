import SwiftUI

final class _Lazy<Value> {
  let initialValue: () -> Value
  lazy var wrappedValue = initialValue()
  init(initialValue: @escaping @autoclosure () -> Value) {
    self.initialValue = initialValue
  }
}

public struct _ScopeStore<ParentState, ParentAction, ChildState, ChildAction, Content: View>: View {
  //  let scopedStore: Store<ChildState, ChildAction>
  @State var scopedStore: _Lazy<Store<ChildState, ChildAction>>
  let content: (Store<ChildState, ChildAction>) -> Content

  init(
    _ store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> ChildState,
    action: @escaping (ChildAction) -> ParentAction,
    @ViewBuilder content: @escaping (Store<ChildState, ChildAction>) -> Content
  ) {
    self._scopedStore = State(wrappedValue: .init(initialValue: store.scope(state: state, action: action)))
    //    self.scopedStore = store.scope(state: state, action: action)
    self.content = content
  }

  public var body: some View {
    self.content(self.scopedStore.wrappedValue)
  }
}
