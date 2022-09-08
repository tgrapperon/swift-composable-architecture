import SwiftUI

public struct ScopeView<ParentState, ParentAction, ChildState, ChildAction, Content: View>: View {
  let store: Store<ParentState, ParentAction>
  @_LazyState var scopedStore: Store<ChildState, ChildAction>
  let content: (Store<ChildState, ChildAction>) -> Content
  public init(
    store: Store<ParentState, ParentAction>,
    state: @escaping (ParentState) -> ChildState,
    action: @escaping (ChildAction) -> ParentAction,
    @StoreViewBuilder<ChildState, ChildAction> content: @escaping (Store<ChildState, ChildAction>) -> Content
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

  // autoclosure instead of deferred doesn't seem to perform as well in terms of counts. (cf. TODO).
  // Need to check why.
}

public protocol StoreView: View {
  associatedtype StoreState
  associatedtype StoreAction
  var store: Store<StoreState, StoreAction> { get }
}

extension StoreView {
  public func Scope<ChildState, ChildAction, Content: View>(
    state: @escaping (StoreState) -> ChildState,
    action: @escaping (ChildAction) -> StoreAction,
    @StoreViewBuilder<ChildState, ChildAction> content: @escaping (Store<ChildState, ChildAction>) -> Content
  ) -> ScopeView<StoreState, StoreAction, ChildState, ChildAction, Content> {
    ScopeView(store: store, state: state, action: action, content: content)
  }
}

//public struct ScopeX<ChildState, ChildAction, Content: View>: View {
//  @_LazyState var scopedStore: Store<ChildState, ChildAction>
//  let content: (Store<ChildState, ChildAction>) -> Content
//  public init<ParentState, ParentAction>(
//    state: @escaping (ParentState) -> ChildState,
//    action: @escaping (ChildAction) -> ParentAction,
//    @StoreViewBuilder<ChildState, ChildAction> content: @escaping (Store<ChildState, ChildAction>) -> Content
//  ) {
////    self.store = store
////    self._scopedStore = .init(wrappedValue: store.scope(state: state, action: action))
////    self.content = content
//    fatalError()
//  }
//
//  public var body: Content {
////    fatalError()
//    content(scopedStore)
//  }
//}

struct AnyStoreKey: EnvironmentKey {
  static var defaultValue: Any { fatalError() }
}

extension EnvironmentValues {
  var store: Any {
    get { self[AnyStoreKey.self] }
    set { self[AnyStoreKey.self] = newValue }
  }
}

//public struct _ScopeX<ParentState, ParentAction, ChildState, ChildAction, Content: View>: View {
//  @Environment(\.store) var store
////  @_LazyState var scopedStore: Store<ChildState, ChildAction>
//  let content: (Store<ChildState, ChildAction>) -> Content
//  public init(
//    state: @escaping (ParentState) -> ChildState,
//    action: @escaping (ChildAction) -> ParentAction,
//    @StoreViewBuilder<ChildState, ChildAction> content: @escaping (Store<ChildState, ChildAction>) -> Content
//  ) {
////    self._scopedStore = .init(wrappedValue: store.scope(state: state, action: action))
////    self.content = content
//  }
//
//  public var body: Content {
////    content(scopedStore)
//    Color.red
//  }
//}

@resultBuilder
public struct StoreViewBuilder<State, Action> {
  public static func buildBlock() -> EmptyView {
    return ViewBuilder.buildBlock()
  }
  public static func buildBlock<Content>(_ content: Content) -> Content where Content: View {
    return ViewBuilder.buildBlock(content)
  }
}
extension StoreViewBuilder {
  public static func buildIf<Content>(_ content: Content?) -> Content? where Content: View {
    return ViewBuilder.buildIf(content)
  }
  public static func buildEither<TrueContent, FalseContent>(first: TrueContent)
    -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View
  {
    return ViewBuilder.buildEither(first: first)
  }
  public static func buildEither<TrueContent, FalseContent>(second: FalseContent)
    -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View
  {
    return ViewBuilder.buildEither(second: second)
  }
}

extension StoreViewBuilder {
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func buildLimitedAvailability<Content>(_ content: Content) -> AnyView
  where Content: View {
    return ViewBuilder.buildLimitedAvailability(content)
  }
}

extension StoreViewBuilder {
  public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)>
  where C0: View, C1: View {
    return ViewBuilder.buildBlock(c0, c1)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)>
  where C0: View, C1: SwiftUI.View, C2: SwiftUI.View {
    return ViewBuilder.buildBlock(c0, c1, c2)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3)
    -> TupleView<(C0, C1, C2, C3)> where C0: View, C1: View, C2: View, C3: View
  {
    return ViewBuilder.buildBlock(c0, c1, c2, c3)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3, C4>(
    _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4
  ) -> TupleView<(C0, C1, C2, C3, C4)> where C0: View, C1: View, C2: View, C3: View, C4: View {
    return ViewBuilder.buildBlock(c0, c1, c2, c3, c4)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3, C4, C5>(
    _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5
  ) -> TupleView<(C0, C1, C2, C3, C4, C5)>
  where C0: View, C1: View, C2: View, C3: View, C4: View, C5: View {
    return ViewBuilder.buildBlock(c0, c1, c2, c3, c4, c5)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3, C4, C5, C6>(
    _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6
  ) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)>
  where C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View {
    return ViewBuilder.buildBlock(c0, c1, c2, c3, c4, c5, c6)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7>(
    _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7
  ) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)>
  where C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View {
    return ViewBuilder.buildBlock(c0, c1, c2, c3, c4, c5, c6, c7)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8>(
    _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8
  ) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)>
  where C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View {
    return ViewBuilder.buildBlock(c0, c1, c2, c3, c4, c5, c6, c7, c8)
  }
}
extension StoreViewBuilder {
  public static func buildBlock<C0, C1, C2, C3, C4, C5, C6, C7, C8, C9>(
    _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8,
    _ c9: C9
  ) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)>
  where
    C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View,
    C9: View
  {
    return ViewBuilder.buildBlock(c0, c1, c2, c3, c4, c5, c6, c7, c8, c9)
  }
}
