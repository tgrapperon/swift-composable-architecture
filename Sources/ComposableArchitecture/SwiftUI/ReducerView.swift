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
      HStack {
        self.child._view
      }
    } label: {
      Text("Scope")
    }
  }
}

extension _IfLetReducer {
  public var _view: AnyView {
    AnyView(view)
  }
  @ViewBuilder var view: some View {
    GroupBox {
      HStack {
        self.child._view
      }
    } label: {
      Text("if let \(String(describing: Child.State.self))?")
    }
  }
}

extension EmptyReducer {
  public var _view: AnyView {
    AnyView(view)
  }
  @ViewBuilder var view: some View {
    //    if #available(iOS 15.0, *) {
    Text("Empty")
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
  }
}

extension ReducerBuilder._Optional {
  public var _view: AnyView {
    AnyView(Group {
      if let wrapped {
        wrapped._view
      } else {
        Text("\(String(describing: Wrapped.self))?")
      }
    })
  }
}

extension ReducerBuilder._Conditional {
  public var _view: AnyView {
    AnyView (
      HStack {
        switch self {
        case let .first(first):
          first._view
          Text("\(String(describing: Second.self))")
        case let .second(second):
          Text("\(String(describing: First.self))")
          second._view
        }
      })
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

extension ReducerBuilder._SequenceMany {
  public var _view: AnyView {
    AnyView(
      Group {
        ForEach(Array(zip(0..., self.reducers)), id: \.0) { index, reducer in
          reducer._view
        }
      }
    )
  }
}


