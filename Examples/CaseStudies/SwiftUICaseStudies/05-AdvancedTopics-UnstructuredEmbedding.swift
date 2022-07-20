import ComposableArchitecture
import SwiftUI

private let readMe = """
This screen demonstrates how multiple independent screens can share state in the Composable \
Architecture. Each tab manages its own state, and could be in separate modules, but changes in \
one tab are immediately reflected in the other.

This tab has its own state, consisting of a count value that can be incremented and decremented, \
as well as an alert value that is set when asking if the current count is prime.

Internally, it is also keeping track of various stats, such as min and max counts and total \
number of count events that occurred. Those states are viewable in the other tab, and the stats \
can be reset from the other tab.
"""

struct UnstructuredContainerState: Equatable {
  struct ItemState: Identifiable, Equatable {
    let id: Int
    var color: Color = .red
    var value: Int = 0
  }

  var color: Color = .blue

  var items: IdentifiedArrayOf<ItemState> = [
    .init(id: 0),
    .init(id: 120),
    .init(id: 42),
  ]
}

extension UnstructuredContainerState {
  func extractItem(id: ItemState.ID) -> ItemState? {
    var value = items[id]
    value.color = color
    return value
  }
}

enum UnstructuredContainerAction {
  enum ItemAction {
    case incr
  }

  case color(Color)
  case item(UnstructuredContainerState.ItemState.ID, ItemAction)
}

let itemReducer = Reducer<UnstructuredContainerState.ItemState, UnstructuredContainerAction.ItemAction, Void> {
  state, action, _ in
  switch action {
  case .incr:
    state.value += 1
    return .none
  }
}

let containerReducer = Reducer<UnstructuredContainerState, UnstructuredContainerAction, Void>.combine(
  itemReducer.forEachUnstructured(
    extract: { containerState, id in
      containerState.extractItem(id: id)
    },
    embed: { containerState, id, item in
      containerState.items[id: id] = item
    },
    action: /UnstructuredContainerAction.item,
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

struct ItemView: View {
  let store: Store<UnstructuredContainerState.ItemState, UnstructuredContainerAction.ItemAction>
  var body: some View {
    WithViewStore(store) { viewStore in
      Text(viewStore.value.formatted())
    }
  }
}

struct UnstructuredContainerView: View {
  let store: Store<UnstructuredContainerState, UnstructuredContainerAction>

  var body: some View {
    List {
//      WithViewStore(store.scope(state: \.color, action: UnstructuredContainerAction.color)) { viewStore in
//        ColorPicker("Color", selection: viewStore.binding(get: { $0 }, send: { $0 }))
//      }
//      ForEachStore
//      <UnstructuredContainerState.ItemState, UnstructuredContainerAction.ItemAction, _, _, _>.init
//      (
//        store,
//        identifiers: { $0.items.ids },
//        extract: { $0.extractItem(id: $1) },
//        action: UnstructuredContainerAction.item,
//        content: ItemView.init(store:)
//      )
    }
  }
}

struct UnstructuredContainer_Preview: PreviewProvider {
  static var previews: some View {
    UnstructuredContainerView(
      store: .init(
        initialState: .init(),
        reducer: containerReducer,
        environment: ()
      )
    )
  }
}
