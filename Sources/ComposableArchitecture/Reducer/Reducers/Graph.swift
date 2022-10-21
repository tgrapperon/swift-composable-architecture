import CustomDump

public indirect enum GraphValue<T> {
  case value(T)
  case node(T, children: [Self])

  var children: [Self] {
    switch self {
    case .value:
      return []
    case .node(_, let children):
      return children
    }
  }
}

extension ReducerGraphValue {
  public struct Parameters {
    var isFlattened: Bool = true
    var isExhaustive: Bool = true
  }
}

extension GraphValue where T == ReducerInfo {
  var typeName: String {
    switch self {
    case .value(let t):
      return t.typeName
    case .node(let t, _):
      return t.typeName
    }
  }
}

public typealias ReducerGraphValue = GraphValue<ReducerInfo>

public struct ReducerInfo: Hashable, Sendable {
  public init(typeName: String, traits: ReducerInfo.Traits = []) {
    self.typeName = typeName
    self.traits = traits
  }
  
  //  public let id: GraphIdentifier<ReducerGraphID>
  public var typeName: String
  public var traits: Traits = []
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
    public static let optional: Traits = .init(rawValue: 1 << 4)
    
    public static let list: Traits = .init(rawValue: 1 << 6)
    public static let modifier: Traits = .init(rawValue: 1 << 7)
    public static let accumulator: Traits = .init(rawValue: 1 << 8)

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
    if remainder.contains(.optional) {
      remainder.remove(.optional)
      components.append("optional")
    }
    if remainder.contains(.list) {
      remainder.remove(.list)
      components.append("list")
    }
    if remainder.contains(.modifier) {
      remainder.remove(.modifier)
      components.append("modifier")
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

//extension ReducerProtocol {
//  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
//    fatalError()
//  }
//}
extension ReducerProtocol where Body == Never {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = _typeName(Self.self, qualified: false)
    return .value(.init(typeName: typeName, traits: .opaque))
  }
}

extension ReducerProtocol where Body: ReducerProtocol {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    //    let path = DependencyValues._current.reducerPath
    let typeName = _typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName)
    let bodyValue = body._graphValue(parameters: parameters)
    switch bodyValue {
    case let .value(_info) where _info.traits.contains(.opaque):
      return .value(info)
    default:
      return .node(info, children: [bodyValue])
    }
  }
}

extension _IfLetReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "IfLet"
    let info = ReducerInfo(typeName: typeName, traits: .optional)
    return .node(info, children: [
      child._graphValue(parameters: parameters),
      parent._graphValue(parameters: parameters)
    ])
  }
}

extension _IfCaseLetReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "IfCaseLet"
    let info = ReducerInfo(typeName: typeName, traits: .optional)
    return .node(info, children: [
      child._graphValue(parameters: parameters),
      parent._graphValue(parameters: parameters)
    ])
  }
}

extension _ForEachReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "ForEach"
    var info = ReducerInfo(typeName: typeName, traits: .list)
    #warning("Quick Recursive fix for now")
    if Parent.State.self == Element.State.self {
      return .node(info, children: [])
    }
    
    let child = self.element._graphValue(parameters: parameters)
    return .node(info, children: [
      child,
      parent._graphValue(parameters: parameters)
    ])
  }
}
//
//extension BindingReducer {
//  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
//    let typeName = "Binding"
//    let info = ReducerInfo(typeName: typeName, traits: [])
//    return .value(info)
//  }
//}

extension _DependencyKeyWritingReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "Dependency"
    let info = ReducerInfo(typeName: typeName, traits: .modifier)
    return .node(
      info,
      children: [
        base._graphValue(parameters: parameters)
      ])
  }
}

extension CombineReducers {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "Combine"
    let info = ReducerInfo(typeName: typeName, traits: .accumulator)
    return .node(
      info,
      children: [
        reducers._graphValue(parameters: parameters)
      ])
  }
}

extension Scope {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = _typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName, traits: .scope)
    return .node(
      info,
      children: [
        child._graphValue(parameters: parameters)
      ])
  }
}

extension Optional {
  public func _graphValue<State, Action>(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue?  where Wrapped: ReducerProtocol, Wrapped.State == State, Wrapped.Action == Action {
    switch self {
    case .none:
      guard parameters.isExhaustive else { return nil }
      let info = ReducerInfo(typeName: _typeName(Wrapped.self, qualified: false), traits: [])
      return .node(info, children: [])
    case .some(let wrapped):
      return wrapped._graphValue(parameters: parameters)
    }
  }
}

extension ReducerBuilder._Optional {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "Optional"
    let info = ReducerInfo(typeName: typeName, traits: .optional)
    if let wrapped = self.wrapped._graphValue(parameters: parameters) {
      return .node(info, children: [wrapped])
    } else {
      return .value(info)
    }
  }
}

extension ReducerBuilder._Conditional {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "Optional"
    let info = ReducerInfo(typeName: typeName, traits: .optional)
    switch self {
    case let .first(first):
      if parameters.isExhaustive {
        let second = ReducerInfo(typeName: _typeName(Second.self, qualified: false))
        return .node(info, children: [
          first._graphValue(parameters: parameters),
          .node(second, children: [])
        ])
      } else {
        return .node(info, children: [first._graphValue(parameters: parameters)])
      }
    case let .second(second):
      if parameters.isExhaustive {
        let first = ReducerInfo(typeName: _typeName(First.self, qualified: false))
        return .node(info, children: [
          .node(first, children: []),
          second._graphValue(parameters: parameters)
        ])
      } else {
        return .node(info, children: [second._graphValue(parameters: parameters)])
      }
    }
  }
}

extension ReducerBuilder._SequenceMany {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let typeName = "SequenceMany"
    let info = ReducerInfo(typeName: typeName, traits: .builderSequence)
    let children = self.reducers.map { $0._graphValue(parameters: parameters) }
    return .node(info, children: children)
  }
}

extension ReducerBuilder._Sequence {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    //    let path = DependencyValues._current.reducerPath
    let typeName = "Sequence"  //_typeName(Self.self, qualified: false)
    let info = ReducerInfo(typeName: typeName, traits: .builderSequence)
    let r0Body = self.r0._graphValue(parameters: parameters)
    let r1Body = self.r1._graphValue(parameters: parameters)
    if parameters.isFlattened {
      switch (r0Body, r1Body) {
      case let (.value(r0), .value(r1)):
        return .node(info, children: [.value(r0), .value(r1)])
      case let (.node(_info, children), .value(r1))
      where _info.traits.contains(.builderSequence):
        return .node(info, children: children + [.value(r1)])
      case let (.value(r0), .node(_info, children))
      where _info.traits.contains(.builderSequence):
        return .node(info, children: [.value(r0)] + children)
      case let (.node(_info0, children0), .node(_info1, children1))
      where _info0.traits.contains(.builderSequence) && _info1.traits.contains(.builderSequence):
        return .node(info, children: children0 + children1)
      case let (.node(_info0, children0), .node(_info1, _))
      where _info0.traits.contains(.builderSequence) && !_info1.traits.contains(.builderSequence):
        return .node(info, children: children0 + [r1Body])
      case let (.node(_info0, _), .node(_info1, children1))
      where !_info0.traits.contains(.builderSequence) && _info1.traits.contains(.builderSequence):
        return .node(info, children: [r0Body] + children1)
      default:
        return .node(info, children: [r0Body, r1Body])
      }
    } else {
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
    print("---")
    customDump(_graphValue(parameters: .init(isFlattened: true, isExhaustive: true)))
    print("***")
    //    }
  }
}
