//
//  File.swift
//  
//
//  Created by Thomas on 20/10/2022.
//

import Foundation
import SwiftUI
extension ReducerProtocol where Body == Never {
  public var _view: AnyView {
    AnyView(view)
  }
  
  @ViewBuilder var view: some View {
    GroupBox {
      Text("func")
        .italic()
    } label: {
      Text("reduce()")
    }
//      .padding(.leading)
  }
}

