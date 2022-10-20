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
      RoundedRectangle(cornerRadius: 3)
        .frame(height: 33)
    } label: {
      Text("func reduce() -> EffectTask<\(String(describing: Self.Action.self))>")
    }
//      .padding(.leading)
  }
}

