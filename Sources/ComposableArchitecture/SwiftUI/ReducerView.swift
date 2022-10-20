import SwiftUI

public struct ReducerView: View {
  let reducer: any ReducerProtocol
  //  let reducerBody: AnyView
  public var body: some View {
    VStack {
      reducer._view as! AnyView
    }
  }

  public init(reducer: any ReducerProtocol) {
    self.reducer = reducer
  }

}

#if DEBUG
  public struct ReducerView_Previews: PreviewProvider {
    public static var previews: some View {
      VStack {
        ReducerView(reducer: MyReducer())
      }
    }
  }
#endif

//extension ReducerProtocol {
//  public var _view: Any {
//    AnyView(Color.orange)
//  }
//}

//extension ReducerProtocol {
//  var view: ReducerView {
//    ReducerView(reducer: self)
//  }
//}

//extension ReducerProtocol where Body == Never {
//  var view: ReducerView<Self> {
//    ReducerView(reducer: self)
//  }
//}
//
//extension ReducerProtocol where Body: ReducerProtocol, {
//  var view: ReducerView<Self> {
//    ReducerView(reducer: self)
//  }
//}

//extension ReducerProtocol {
//  func view() -> AnyView where Body == Never {
//    AnyView(ReducerView(reducer: self))
//  }
//  func view() -> AnyView where Body: ReducerProtocol, Body.Body: ReducerProtocol {
//    AnyView(ReducerView(reducer: self))
//  }
//  func view() -> AnyView where Body: ReducerProtocol, Body.Body == Never {
//    AnyView(ReducerView(reducer: self))
//  }
//}

//extension ReducerProtocol where Body: ReducerProtocol {
//  var view: AnyView {
//    AnyView(Color.red)
//  }
//}
//
//extension ReducerProtocol where Body == Never {
//  var view: AnyView {
//    AnyView(Color.blue)
//  }
//}

struct MyReducer: ReducerProtocol {
  typealias State = String
  typealias Action = Int
  var body: some ReducerProtocol<String, Int> {
    EmptyReducer()
    EmptyReducer()
    Reduce({ _, _ in .none
    })
  }
}

extension Scope {
  public var _view: AnyView {
    AnyView(view)
  }
  @ViewBuilder var view: some View {
    GroupBox {
        self.child._view
    } label: {
      Text("Scope")
    }
    .padding()
  }
}

extension EmptyReducer {
  public var _view: AnyView {
    AnyView(view)
  }
  @ViewBuilder var view: some View {
    //    if #available(iOS 15.0, *) {
    Text("Empty")
      .padding()
  }
}

extension Reduce {
  public var _view: AnyView {
    AnyView(view)
  }
  @ViewBuilder var view: some View {
    GroupBox {
      Text("…")
    } label: {
      Text("Reduce")
    }
      .padding()
  }
}

extension ReducerBuilder._Optional {
  public var _view: AnyView {
    AnyView(Color.orange)
  }
}

extension ReducerBuilder._Sequence {
  public var _view: AnyView {
    AnyView(
      Group {
        self.r0._view
        self.r1._view
      }
    )
  }
}

//extension ReducerProtocol where Body == Never {
//  public var view: AnyView {
//    AnyView(Color.green)
//  }
//}
//
//extension ReducerProtocol where Body: ReducerProtocol {
//  public var view: AnyView {
//    AnyView(ReducerView(reducer: body))
//  }
//}

//extension ReducerProtocol where Body: ReducerProtocol {
//  var view: AnyView {
////    AnyView(Rectangle())
//  }
//}

//extension Reduce {
//  var view: AnyView {
//    AnyView(Ellipse())
//  }
//}
