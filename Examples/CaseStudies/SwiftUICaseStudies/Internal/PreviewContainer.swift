import SwiftUI

struct PreviewContainer<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }
  
  var body: some View {
    #if os(iOS)
    NavigationStack {
      content
    }
    #else
    content
      .frame(maxWidth: 400)
      .padding()
    #endif
  }
}

struct PreviewContainer_Previews: PreviewProvider {
  static var previews: some View {
    PreviewContainer {
      Text("Preview")
    }
  }
}
