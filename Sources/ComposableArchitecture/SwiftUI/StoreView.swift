import SwiftUI

public protocol ViewStateProtocol: Equatable {
  associatedtype State
  init(state: State)
}

public protocol ViewActionProtocol {
  associatedtype Action
  static func embed(_ action: Self) -> Action
}

public protocol StoreView: View where Body == WithViewStore<ViewState, ViewAction, StoreBody> {
  associatedtype StoreState
  associatedtype StoreAction
  associatedtype ViewState = StoreState
  associatedtype ViewAction = StoreAction
  associatedtype StoreBody: View
  var _body: Body { get }

  var store: Store<StoreState, StoreAction> { get }
  func body(viewStore: ViewStore<ViewState, ViewAction>) -> StoreBody
}

extension StoreView {
  public var body: Body { _body }
}

extension StoreView
where
  ViewState == StoreState,
  StoreState: Equatable,
  ViewAction == StoreAction
{
  public var _body: Body {
    WithViewStore(store, observe: { $0 }, content: self.body(viewStore:))
  }
}

extension StoreView
where
  ViewState: ViewStateProtocol,
  ViewState.State == StoreState,
  ViewAction == StoreAction
{
  public var _body: Body {
    WithViewStore(store, observe: ViewState.init(state:), content: self.body(viewStore:))
  }
}

extension StoreView
where
  ViewState == StoreState,
  StoreState: Equatable,
  ViewAction: ViewActionProtocol,
  ViewAction.Action == StoreAction
{
  public var _body: Body {
    WithViewStore(
      store, observe: { $0 }, send: ViewAction.embed(_:), content: self.body(viewStore:))
  }
}

extension StoreView
where
  ViewState: ViewStateProtocol,
  ViewState.State == StoreState,
  ViewAction: ViewActionProtocol,
  ViewAction.Action == StoreAction
{
  public var _body: Body {
    WithViewStore(
      store, observe: ViewState.init(state:), send: ViewAction.embed(_:),
      content: self.body(viewStore:))
  }
}





enum AA {
  case one
  case two
  case three
}

struct TestView: StoreView {
  var store: Store<CGPoint, AA>
  func body(viewStore: ViewStore<CGPoint, AA>) -> some View {
    Color.red
  }
}

struct TestView2: StoreView {
  let store: Store<CGPoint, AA>

  struct ViewState: ViewStateProtocol {
    let x: CGFloat
    init(state: StoreState) {
      self.x = state.x
    }
  }

  func body(viewStore: ViewStore<ViewState, AA>) -> some View {
    Color.red
  }
}

struct TestViewVSVA: StoreView {
  let store: Store<CGPoint, AA>

  struct ViewState: ViewStateProtocol {
    let x: CGFloat
    init(state: CGPoint) {
      self.x = state.x
    }
  }
  
  enum ViewAction: ViewActionProtocol {
    case one
    case two
    
    static func embed(_ action: Self) -> AA {
      switch action {
      case .one: return .one
      case .two: return .two
      }
    }
  }

  func body(viewStore: ViewStore<ViewState, ViewAction>) -> some View {
    Color.red
  }
}

//struct MyTest: StoreView {
//  var store: Store<CGPoint, AA>
//  
//  func body(viewStore: ViewStore<ViewState, ViewAction>) -> some View {
//    
//  }
//}


func test() {
  let s = Store<CGPoint, AA>(initialState: .init(), reducer: EmptyReducer())
  let test = TestView2(store: s)
}

// extension StoreView {
//  public var body: Body {
//    let viewStore = ViewStore(store, removeDuplicates: { _, _ in false })
//    self.body(viewStore: viewStore)
//  }
// }
