import CustomDump
public indirect enum GraphValue<T> {
  case value(T)
  case node(T, children: [Self])
}

public typealias ReducerGraphValue = GraphValue<ReducerInfo>


public struct ReducerInfo: Hashable, Sendable {
//  public let id: GraphIdentifier<ReducerGraphID>
  var typeName: String
  var traits: Traits = []
}

extension ReducerInfo: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    "\(typeName), traits: \(traits.customDumpDescription)"
  }
}

extension ReducerInfo {
  public struct Traits: RawRepresentable, OptionSet, Hashable, Sendable {
    public var rawValue: Int
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }
    public static let opaque: Traits = .init(rawValue: 1 << 1)
    public static let builderSequence: Traits = .init(rawValue: 1 << 2)
    public static let scope: Traits = .init(rawValue: 1 << 3)

  }
}

extension ReducerInfo.Traits: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    guard !isEmpty else { return "none" }
    var components: [String] = []
    var remainder = self
    if remainder.contains(.opaque) {
      remainder.remove(.opaque)
      components.append("opaque")
    }
    if remainder.contains(.builderSequence) {
      remainder.remove(.builderSequence)
      components.append("sequence")
    }
    if remainder.contains(.scope) {
      remainder.remove(.scope)
      components.append("scope")
    }
    if !remainder.isEmpty {
      components.append("Unknown: \(remainder.rawValue)")
    }
    return "[\(components.joined(separator: ", "))]"
  }
}

//extension ReducerInfo {
//  init<R: ReducerProtocol>(reducer: R) {
//    self.typeName = _typeName(R.self, qualified: false)
//    self.id = .init(id: ObjectIdentifier(R.self), path: path)
//  }
//
//  init<R: ReducerProtocol>(
//    reducer: R,
//    typeName: String,
//    path: [GraphIdentifier<ReducerGraphID>]
//  ) where R.Body: ReducerProtocol {
//    self.typeName = typeName
//    self.id = .init(id: ObjectIdentifier(R.self), path: path)
//  }
//}

extension ReducerProtocol {
  public var _graphValue: ReducerGraphValue {
    fatalError()
  }
}
extension ReducerProtocol where Body == Never {
  public var _graphValue: ReducerGraphValue {
    let typeName = _typeName(Self.self, qualified: false)
    return .value(.init(typeName: typeName, traits: .opaque))
  }
}

extension ReducerProtocol where Body: ReducerProtocol {
  public var _graphValue: ReducerGraphValue {
//    let path = DependencyValues._current.reducerPath
    let typeName = _typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName)
    let bodyValue = body._graphValue
    switch bodyValue {
    case let .value(_info) where _info.traits.contains(.opaque):
      return .value(info)
    default:
      return .node(info, children: [bodyValue])
    }
  }
}

extension _IfLetReducer {
  public var _graphValue: ReducerGraphValue {
//    let path = DependencyValues._current.reducerPath
    let typeName = _typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName)
    return .node(info, children: [child._graphValue])
  }
}

extension Scope {
  public var _graphValue: ReducerGraphValue {
//    let path = DependencyValues._current.reducerPath
    let typeName = _typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName, traits: .scope)
    return .node(info, children: [child._graphValue])
  }
}

extension ReducerBuilder._Sequence {
  public var _graphValue: ReducerGraphValue {
//    let path = DependencyValues._current.reducerPath
    let typeName = "Sequence"//_typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName, traits: .builderSequence)
    let r0Body = self.r0._graphValue
    let r1Body = self.r1._graphValue
    switch (r0Body, r1Body) {
    case let (.value(r0), .value(r1)):
      return .node(info, children: [.value(r0), .value(r1)])
    case let (.node(_info, children), .value(r1)) where _info.traits.contains(.builderSequence):
      return .node(info, children: children + [.value(r1)])
    case let (.value(r0), .node(_info, children)) where _info.traits.contains(.builderSequence):
      return .node(info, children: [.value(r0)] + children)
    case let (.node(_info0, children0), .node(_, children1)) where _info0.traits.contains(.builderSequence):
      return .node(info, children: children0 + children1)
    default:
      return .node(info, children: [r0Body, r1Body])
    }

  }
}

//struct ReducerPath: DependencyKey {
//  static var liveValue: [GraphIdentifier<ReducerGraphID>] = []
//  static var testValue: [GraphIdentifier<ReducerGraphID>] = []
//}
//
//extension DependencyValues {
//  var reducerPath: [GraphIdentifier<ReducerGraphID>] {
//    get { self[ReducerPath.self] }
//    set { self[ReducerPath.self] = newValue }
//  }
//}

extension ReducerProtocol {
  public func printGraphValue() {
//    let _ = DependencyValues.withValue(\.reducerPath, []) {
      customDump(_graphValue)
//    }
  }
}
