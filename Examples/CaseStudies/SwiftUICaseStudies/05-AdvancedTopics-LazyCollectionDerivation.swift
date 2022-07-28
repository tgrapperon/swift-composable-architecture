import ComposableArchitecture
import SwiftUI

private let readMe = """
  This study shows the performance difference between lazy and eager \
  collection embedding. Both features are similar: an array of 50k items that shares a common \
  `color` value. Only the first 100 items are presented in both cases to avoid the \
  ineluctable impact of diffing 50k identifiers which is not the topic of this study.\
  
  One can check how changing the color is relatively fast in the lazy case,\
  whereas it is much more laggy/glitchy in the eager one. The lazy conversion \
  furthermore allows to automatically update the parent from any child \
  modification, which is only possible to achieve manually from within a reducer \
  in the eager case.
  """

private let numberOfItems: Int = 50_000
private let numberOfPresentedItems: Int = 100

enum LazyCollectionDerivationStudy {
  struct ItemState: Identifiable, Equatable {
    let id: String
    var color: Color = .red
    var value: Int = 0
  }
  
  enum ItemAction {
    case incr
    case color(Color)
  }
  
  static let itemReducer = Reducer<ItemState, ItemAction, Void> {
    state, action, _ in
    switch action {
    case let .color(color):
      state.color = color
      return .none
    case .incr:
      state.value += 1
      return .none
    }
  }
  
  static let initialItems: IdentifiedArrayOf<ItemState> =
  IdentifiedArray(uncheckedUniqueElements: (0..<numberOfItems)
    .map { ItemState(id: "\($0)", value: $0) })
  
  struct LazyConversionState {
    var color: Color = .blue
    var items: IdentifiedArrayOf<ItemState> = initialItems
    
    static let itemsConversion = LazyIdentifiedArrayConversion(\Self.items)
    { `self`, id, item in
      item.color = self.color
    } updateSource: { `self`, id, item in
      // This is not a good idea an this should be performed in a reducer,
      // otherwise an action not changing the color could overwrite the parent's
      // color.
      self.color = item.color
    }
  }
  
  struct EagerConversionState {
    var color: Color = .blue
    var _items: IdentifiedArrayOf<ItemState> = initialItems
    var items: IdentifiedArrayOf<ItemState> {
      get {
        var items = _items
        for id in items.ids {
          items[id: id]?.color = color
        }
        return items
      }
      set { _items = newValue }
    }
  }
  
  enum Action {
    case color(Color)
    case item(ItemState.ID, ItemAction)
  }
  
  static let lazyConversionReducer = Reducer<
    LazyConversionState, Action, Void
  >.combine(
    itemReducer.forEachLazy(
      conversion: LazyConversionState.itemsConversion,
      action: /Action.item,
      environment: { $0 }),
    .init { state, action, _ in
      switch action {
      case let .color(color):
        state.color = color
        return .none
      case .item:
        return .none
      }
    }
  )
  
  static let eagerConversionReducer = Reducer<
    EagerConversionState, Action, Void
  >.combine(
    itemReducer.forEach(
      state: \.items,
      action: /Action.item,
      environment: { $0 }),
    .init { state, action, _ in
      switch action {
      case let .color(color):
        state.color = color
        return .none
      case let .item(_, .color(color)):
        // We need to manually update the parent's color.
        // In the `lazy` case, this is performed automatically
        // during the conversion.
        state.color = color
        return .none
      case .item:
        return .none
      }
    }
  )
  
  struct ItemView: View {
    let store: Store<ItemState, ItemAction>
    var body: some View {
      WithViewStore(store) { viewStore in
        HStack {
          ColorPicker(selection: viewStore.binding(get: \.color, send: ItemAction.color)) {
            Text("Shared color")
          }.labelsHidden()
          Text("__Item #\(viewStore.id)__ Value: \(viewStore.value.formatted())")
          Spacer()
          Button("Incr") {
            viewStore.send(.incr)
          }
        }
        .monospacedDigit()
      }
    }
  }
  
  struct LazyConversionView: View {
    let store: Store<LazyConversionState, Action>
    
    var body: some View {
      List {
        WithViewStore(
          store.scope(
            state: \.color,
            action: Action.color
          )
        ) {
          viewStore in
          ColorPicker("Color", selection: viewStore.binding(get: { $0 }, send: { $0 }))
        }
        ForEachLazyStore(
          store,
          conversion: LazyConversionState.itemsConversion,
          action: Action.item,
          content: ItemView.init(store:)
        )
      }
    }
  }
  
  struct EagerConversionView: View {
    let store: Store<EagerConversionState, Action>
    
    var body: some View {
      List {
        WithViewStore(
          store.scope(
            state: \.color,
            action: Action.color
          )
        ) {
          viewStore in
          ColorPicker("Color", selection: viewStore.binding(get: { $0 }, send: { $0 }))
        }
        ForEachStore(
          store.scope(
            state: {
              IdentifiedArrayOf($0.items.prefix(numberOfPresentedItems))
            }, action: Action.item), content: ItemView.init(store:))
      }
    }
  }
}
extension LazyCollectionDerivationStudy {
  struct StudyState {
    var lazyConversionState: LazyConversionState = .init()
    var eagerConversionState: EagerConversionState = .init()
  }
}

extension LazyCollectionDerivationStudy {
  enum StudyAction {
    case lazy(Action)
    case eager(Action)
  }
}


let lazyCollectionDerivationStudyReducer = Reducer<LazyCollectionDerivationStudy.StudyState, LazyCollectionDerivationStudy.StudyAction, Void>.combine(
  LazyCollectionDerivationStudy.eagerConversionReducer
    .pullback(
      state: \.eagerConversionState,
      action: /LazyCollectionDerivationStudy.StudyAction.eager,
      environment: { $0 }
    ),
  LazyCollectionDerivationStudy.lazyConversionReducer
    .pullback(
      state: \.lazyConversionState,
      action: /LazyCollectionDerivationStudy.StudyAction.lazy,
      environment: { $0 }
    )
)

struct LazyCollectionDerivationStudyView: View {
  let store: Store<
    LazyCollectionDerivationStudy.StudyState,
    LazyCollectionDerivationStudy.StudyAction
  >
  var body: some View {
    List {
      Section {
        AboutView(readMe: readMe)
      }
      NavigationLink {
        LazyCollectionDerivationStudy.EagerConversionView(store: store.scope(
          state: \.eagerConversionState,
          action: LazyCollectionDerivationStudy.StudyAction.eager
        ))
        .navigationTitle("Eager")
      } label: {
        Text("Eager")
      }
      NavigationLink {
        LazyCollectionDerivationStudy.LazyConversionView(store: store.scope(
          state: \.lazyConversionState,
          action: LazyCollectionDerivationStudy.StudyAction.lazy
        ))
        .navigationTitle("Lazy")
      } label: {
        Text("Lazy")
      }
    }
    .navigationTitle("Lazy Collection Derivation")
  }
}

struct LazyCollectionDerivationStudy_Preview: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LazyCollectionDerivationStudyView(
        store: .init(
          initialState: .init(),
          reducer: lazyCollectionDerivationStudyReducer,
          environment: ()
        )
      )
    }
  }
}
