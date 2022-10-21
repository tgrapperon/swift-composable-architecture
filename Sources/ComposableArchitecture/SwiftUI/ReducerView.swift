import SwiftUI

struct ReducerView: View {
  init(_ graphValue: ReducerGraphValue) {
    self.graphValue = graphValue
  }
  
  let graphValue: ReducerGraphValue
  var body: some View {
    Text( /*@START_MENU_TOKEN@*/"Hello, World!" /*@END_MENU_TOKEN@*/)
  }
}

public struct Reducer1: ReducerProtocol {
  public typealias State = Int
  public typealias Action = Void
  public var body: some ReducerProtocol<Int, Void> {
    EmptyReducer()
    Reduce({ state, action in
      state += 1
      return .none
    })
  }
}

struct ReducerView_Previews: PreviewProvider {
  static var previews: some View {
    ReducerView(
      Reducer1()._graphValue(parameters: .init())
    )
  }
}
