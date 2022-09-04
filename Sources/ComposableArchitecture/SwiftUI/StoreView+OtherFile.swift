import SwiftUI
struct SwiftUIView: StoreView {
  let store: Store<Int, Void>

  func body(viewStore: ViewStore<Int, Void>) -> some View {
    Text("Hello! \(viewStore.state)")
  }
}

struct SwiftUIView2: StoreView {
  let store: Store<Int, Void>

  struct ViewState: ViewStateProtocol {
    var isEven: Bool
    init(_ state: Int) {
      isEven = state.isMultiple(of: 2)
    }
  }

  func body(viewStore: ViewStore<ViewState, Void>) -> some View {
    Text("isEven: \(viewStore.state.isEven ? "Yes" : "No")")
  }
}

struct SwiftUIView_Previews: PreviewProvider {
  static let store = Store(
    initialState: 0,
    reducer: Reducer<Int, Void, Void>.empty,
    environment: ()
  )
  static var previews: some View {
    VStack {
      SwiftUIView(store: store)
      SwiftUIView2(store: store)
    }
  }
}
