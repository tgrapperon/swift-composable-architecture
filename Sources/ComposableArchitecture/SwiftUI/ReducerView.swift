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
      HStack {
        Text(info.state)
        Text(info.action)
      }
      VStack {
        switch graphValue {
        case  .value:
          EmptyView()
        case let .node(_, children):
          ForEach(children) { child in
            ReducerView(child)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Text(info.type)
    }
    .fixedSize(horizontal: true, vertical: false)
  }
}

public struct Reducer1: ReducerProtocol {
  public typealias State = Int
  public typealias Action = Void
  public var body: some ReducerProtocol<Int, Void> {
    EmptyReducer()
    EmptyReducer()
    Reduce({ state, action in
      state += 1
      return .none
    })
  }
}

@available(macOS 13.0, iOS 16, *)
struct ReducerView_Previews: PreviewProvider {
  static var previews: some View {
    ReducerView(
      Reducer1()._graphValue(parameters: .init())
    )
    .padding()
  }
}
