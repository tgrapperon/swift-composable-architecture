//
//  File 2.swift
//  
//
//  Created by Thomas on 20/10/2022.
//

import Foundation
import SwiftUI
extension ReducerProtocol where Body: ReducerProtocol, Body.State == State, Body.Action == Action {
  
  public var _view: AnyView {
    AnyView(view)
  }
  
  @ViewBuilder var view: some View {
    GroupBox {
      VStack {
        ReducerView(reducer: body)
      }
    } label: {
      Text("\(String(describing: Self.self))")
    }
//    .padding(.leading)
  }
}
