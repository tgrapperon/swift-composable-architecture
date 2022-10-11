import SwiftUI

struct AboutView: View {
  let readMe: String
  #if os(macOS)
  @State var isPresented: Bool = false
  #endif
  
  var body: some View {
    #if os(iOS)
    DisclosureGroup("About this case study") {
      Text(template: self.readMe)
    }
    #elseif os(macOS)
    Color.clear
      .fixedSize()
    .toolbar {
      Button {
        isPresented = true
      } label: {
        Label("About this case study", systemImage: "info.circle.fill")
      }
      .sheet(isPresented: $isPresented) {
        VStack(alignment: .leading, spacing: 20) {
          Text("About this case study")
            .font(.system(.title3, weight: .bold))
          Text(template: self.readMe)
            .font(.callout)
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: true)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
              isPresented = false
            }
          }
        }
        .padding()
      }
    }
    #endif
  }
}

