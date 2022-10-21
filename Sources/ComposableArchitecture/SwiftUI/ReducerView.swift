import SwiftUI

@available(macOS 13.0, iOS 16, *)
public struct ReducerView: View {
  public init(_ graphValue: ReducerGraphValue) {
    self.graphValue = graphValue
  }
  
  let graphValue: ReducerGraphValue
  var info: ReducerInfo { graphValue.info }
  public var body: some View {
    GroupBox {
      VStack {
        switch graphValue {
        case let .value(info):
          reducerInfoView(info: info)
        case let .node(_, children):
          ForEach(children) { child in
            reducerView(value: child)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Text(info.type)
    }
    .fixedSize(horizontal: true, vertical: false)
  }
  
  @ViewBuilder
  func reducerView(value: ReducerGraphValue) -> some View {
    switch value.info.traits {
    case let traits where traits.contains(.scope):
      ScopeView(value)
    default:
      ReducerView(value)
    }
  }
  
  @ViewBuilder
  func reducerInfoView(info: ReducerInfo) -> some View {
    HStack {
      Text(info.type)
      Text(info.state)
      Text(info.action)
    }
  }
  
}

@available(macOS 13.0, iOS 16, *)
struct ScopeView: View {
  public init(_ graphValue: ReducerGraphValue) {
    self.graphValue = graphValue
  }
  
  let graphValue: ReducerGraphValue
  var info: ReducerInfo { graphValue.info }
  var body: some View {
    
    switch self.graphValue {
    case let .value(reducer):
      ReducerView(.value(reducer))
        .padding(.leading, 33)
        .background {
          Color.blue
        }
    case let .node(t, children: children):
      HStack {
        Text("\(String(describing: t.type))")
        Text("\(children.count)")
      }
      ForEach(children) { child in
        ReducerView(child)
      }
      .padding(.leading, 33)
      .background {
        Color.green
      }
    }
    
  }
}

public struct Reducer1: ReducerProtocol {
  public typealias State = CGPoint
  public typealias Action = Void
  public var body: some ReducerProtocol<CGPoint, Void> {
    Scope(state: \.x, action: .self) {
      Reducer2()
      Reducer2()
      Reduce ({ _, _ in .none })
//      Reduce ({ _, _ in .none })
    }
    EmptyReducer()
    Reduce({ state, action in
      state.x += 1
      return .none
    })
  }
}

public struct Reducer2: ReducerProtocol {
  public typealias State = CGFloat
  public typealias Action = Void
  public var body: some ReducerProtocol<CGFloat, Void> {
    Reduce({ state, action in
      state += 1
      return .none
    })
  }
}
let value = Reducer1()._graphValue(parameters: .init())

@available(macOS 13.0, iOS 16, *)
struct ReducerView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      ReducerView(value)
      .padding()
//      let text = "\(customDump(value))"
//      TextEditor(text: .constant(text))
//        .font(.caption2.monospaced())
//        .frame(height: 667)
    }
  }
}
