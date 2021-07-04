import Foundation

let indent = "  "

func printTypeDeclaration(_ type: String = "enum", name: String, n: Int = 50, property: (Int) -> String = { "case action\($0)" }) {
  var lines: [String] = []
  lines.append("\(type) \(name): Equatable {")
  for i in 0..<n {
    lines.append(indent + property(i))
  }
  lines.append("}")
  let declaration = lines.joined(separator: "\n")
  print(declaration)
}


//printTypeDeclaration("enum", name: "SimpleAction") { "case action\($0)" }
//printTypeDeclaration("enum", name: "ComposedAction") { "case action\($0)(SimpleAction)" }
//printTypeDeclaration("struct", name: "SimpleState") { #"var value\#($0): String = "\#(UUID().uuidString)" "# }
//printTypeDeclaration("struct", name: "ComposedState") { #"var value\#($0): SimpleState = .init() "# }

//do {
//  var lines: [String] = []
//  for i in 0..<50 {
//    let line = """
//    case .action\(i):
//      state.value\(i) += \"\(i)\"
//      return .none
//    """
//    lines.append(line)
//  }
//  let declaration = lines.joined(separator: "\n")
//  print(declaration)
//}

//do {
//  var lines: [String] = []
//  for i in 0..<50 {
//    let line = """
//    simpleReducer.pullback(state: \\ComposedState.value\(i), action: /ComposedAction.action\(i), environment: { _ in ()}),
//    """
//    lines.append(line)
//  }
//  let declaration = lines.joined(separator: "\n")
//  print(declaration)
//}

do {
  var lines: [String] = []
  for i in 0..<50 {
    let line = """
    viewStore.send(.action\(i)(.action\(i)))
    """
    lines.append(line)
  }
  let declaration = lines.joined(separator: "\n")
  print(declaration)
}
