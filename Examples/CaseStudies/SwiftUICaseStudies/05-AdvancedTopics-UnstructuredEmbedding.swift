import ComposableArchitecture
import SwiftUI

private let readMe = """
  This study shows the performance difference between unstructured and structured \
  embedding. Both features are similar: an array of 50k items that shares a common \
  `color` value. Only the first 100 items are presented in both cases to avoid the \
  ineluctable impact of diffing 50k identifiers which is not the topic of this study.\
  
  One can check how changing the color is relatively fast in the unstructured case,\
  whereas it is much more laggy/glitchy in the strucured one.
  """

private let numberOfItems: Int = 50_000
private let numberOfPresentedItems: Int = 100

struct UnstructuredStudy {
  struct ItemState: Identifiable, Equatable {
    let id: String
    var color: Color = .red
    var value: Int = 0
  }

  enum ItemAction {
    case incr
  }

  static let itemReducer = Reducer<ItemState, ItemAction, Void> {
    state, action, _ in
    switch action {
    case .incr:
      state.value += 1
      return .none
    }
  }

  static let initialItems: IdentifiedArrayOf<ItemState> = IdentifiedArray(
    uncheckedUniqueElements: (0..<numberOfItems).map {
      ItemState(id: "\($0)", value: $0)
    })

  struct UnstructuredState {
    var color: Color = .blue
    var items: IdentifiedArrayOf<ItemState> = initialItems

    func extractItem(id: ItemState.ID) -> ItemState? {
      var value = items[id: id]
      value?.color = color
      return value
    }
  }

  struct StructuredState {
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

  static let unstructuredReducer = Reducer<
    UnstructuredState, Action, Void
  >.combine(
    itemReducer.forEachUnstructured(
      extract: { containerState, id in
        containerState.extractItem(id: id)
      },
      embed: { containerState, id, item in
        containerState.items[id: id] = item
      },
      action: /Action.item,
      environment: { $0 }
    ),
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

  static let structuredReducer = Reducer<
    StructuredState, Action, Void
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
          Text("Shared")
            .bold()
            .padding(8)
            .colorInvert()
            .blendMode(.difference)
            .background(viewStore.color)
            .cornerRadius(9)
          Text(viewStore.value.formatted())
          Spacer()
          Button("Incr") {
            viewStore.send(.incr)
          }
        }
      }
    }
  }

  struct UnstructuredView: View {
    let store: Store<UnstructuredState, Action>

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
        ForEachUnstructuredStore(
          store: store,
          state: { IdentifiedArrayOf($0.items.prefix(numberOfPresentedItems)) },
          action: Action.item,
          extract: { UnstructuredState.extractItem($1)(id: $0) },
          content: ItemView.init(store:)
        )
      }
    }
  }

  struct StructuredView: View {
    let store: Store<StructuredState, Action>

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

  var unstructuredState: UnstructuredState = .init()
  var structuredState: StructuredState = .init()
}

enum UnstructuredStudyAction {
  case structured(UnstructuredStudy.Action)
  case unstructured(UnstructuredStudy.Action)
}

let unstructuredStudyReducer = Reducer<UnstructuredStudy, UnstructuredStudyAction, Void>.combine(
  UnstructuredStudy.structuredReducer
    .pullback(
      state: \.structuredState,
      action: /UnstructuredStudyAction.structured,
      environment: { $0 }
    ),
  UnstructuredStudy.unstructuredReducer
    .pullback(
      state: \.unstructuredState,
      action: /UnstructuredStudyAction.unstructured,
      environment: { $0 }
    )
)

struct UnstructuredStudyView: View {
  let store: Store<UnstructuredStudy, UnstructuredStudyAction>
  var body: some View {
    List {
      Section {
        AboutView(readMe: readMe)
      }
      NavigationLink {
        UnstructuredStudy.StructuredView(store: store.scope(
          state: \.structuredState,
          action: UnstructuredStudyAction.structured
        ))
      } label: {
        Text("Structured")
      }
      NavigationLink {
        UnstructuredStudy.UnstructuredView(store: store.scope(
          state: \.unstructuredState,
          action: UnstructuredStudyAction.unstructured
        ))
      } label: {
        Text("Unstructured")
      }
    }
    .navigationTitle("Unstructured Embedding")
  }
}

struct UnstructuredContainer_Preview: PreviewProvider {
  static var previews: some View {
    NavigationView {
      UnstructuredStudyView(
        store: .init(
          initialState: .init(),
          reducer: unstructuredStudyReducer,
          environment: ()
        )
      )
    }
  }
}
