/// Acts as a namespace for types with extended support
public struct Legacy {}

import SwiftUI
public struct LegacyView<Content: View>: View {
  let content: Content
  public var body: some View { content }
}

extension View {
  public var legacy: LegacyView<Self> { .init(content: self) }
}
