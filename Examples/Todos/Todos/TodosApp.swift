@_spi(Instruments) import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    let _ = Instrumentation.shared.enable()
    WindowGroup {
      AppView(
        store: Store(
          initialState: Todos.State(),
          reducer: Todos()._printChanges()
        )
      )
    }
  }
}
