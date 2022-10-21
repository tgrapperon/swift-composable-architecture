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

extension GraphValue: Equatable where T: Equatable {}
extension GraphValue: Hashable where T: Hashable {}
extension GraphValue: Sendable where T: Sendable {}
extension GraphValue: Codable where T: Codable {}

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

  func with(traits: (inout ReducerInfo.Traits) -> Void) -> Self {
    switch self {
    case .value(var t):
      traits(&t.traits)
      return .value(t)
    case .node(var t, let children):
      traits(&t.traits)
      return .node(t, children: children)
    }
  }
}

extension GraphValue: CustomDumpReflectable where T == ReducerInfo {
  public var customDumpMirror: Mirror {
    switch self {
    case .value(let t):
     return Mirror(self, children: [
        "info": t
     ], displayStyle: .struct)
    case .node(let t, let children):
      return Mirror(self, children: [
        "info": t,
        "children": children
      ], displayStyle: .struct)
    }
  }
}

public typealias ReducerGraphValue = GraphValue<ReducerInfo>

public struct ReducerInfo: Hashable, Sendable, Codable {
  init(
    typeName: String,
    state: String,
    action: String,
    traits: ReducerInfo.Traits = []
  ) {
    self.typeName = typeName
    self.name = typeName
    self.state = state
    self.action = action
    self.traits = traits
  }

  init<R: ReducerProtocol>(
    _ reducer: R.Type,
    name: String? = nil,
    traits: ReducerInfo.Traits = []
  ) {
    self.typeName = _typeName(reducer, qualified: true)
    self.name = name ?? _typeName(reducer, qualified: false)
    self.state = _typeName(reducer.State.self, qualified: true)
    self.action = _typeName(reducer.Action.self, qualified: true)
    self.traits = traits
  }

  public var name: String
  public var typeName: String
  public var state: String
  public var action: String
  public var traits: Traits = []
}

extension ReducerInfo: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(self, children: [
      "name": name,
      "traits": traits
    ], displayStyle: .struct)
  }
}


extension ReducerInfo {
  public struct Traits: RawRepresentable, OptionSet, Hashable, Sendable, Codable {
    public var rawValue: Int
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }
    public static let opaque: Traits = .init(rawValue: 1 << 1)
    public static let builderSequence: Traits = .init(rawValue: 1 << 2)
    public static let scope: Traits = .init(rawValue: 1 << 3)
    public static let optional: Traits = .init(rawValue: 1 << 4)
    public static let conditional: Traits = .init(rawValue: 1 << 5)

    public static let switchCase: Traits = .init(rawValue: 1 << 6)
    public static let store: Traits = .init(rawValue: 1 << 7)

    public static let list: Traits = .init(rawValue: 1 << 10)
    public static let modifier: Traits = .init(rawValue: 1 << 11)
    public static let modified: Traits = .init(rawValue: 1 << 12)

    public static let group: Traits = .init(rawValue: 1 << 13)
    public static let builder: Traits = .init(rawValue: 1 << 14)

    public static let empty: Traits = .init(rawValue: 1 << 20)
    public static let binding: Traits = .init(rawValue: 1 << 21)
    public static let debug: Traits = .init(rawValue: 1 << 22)
  }
}

extension ReducerInfo.Traits: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    guard !isEmpty else { return "none" }
    var components: [String] = []
    var remainder = self
    func consume(_ trait: Self, _ description: String) {
      if remainder.contains(trait) {
        remainder.remove(trait)
        components.append(description)
      }
    }
    consume(.opaque, "opaque")
    consume(.builderSequence, "builderSequence")
    consume(.scope, "scope")
    consume(.optional, "optional")
    consume(.switchCase, "switchCase")
    consume(.list, "list")
    consume(.modifier, "modifier")
    consume(.modified, "modified")
    consume(.group, "group")
    consume(.binding, "binding")
    consume(.builder, "builder")
    consume(.empty, "empty")
    consume(.debug, "debug")

    if !remainder.isEmpty {
      components.append("Unknown: \(remainder.rawValue)")
    }
    return "[\(components.joined(separator: ", "))]"
  }
}

extension ReducerProtocol where Body == Never {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    return .value(.init(Self.self, traits: .opaque))
  }
}

extension ReducerProtocol where Body: ReducerProtocol {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    //    let path = DependencyValues._current.reducerPath
    let info = ReducerInfo(Self.self)
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
    let info = ReducerInfo(
      Self.self,
      name: "IfLet",
      traits: .optional
    )
    return .node(
      info,
      children: [
        child._graphValue(parameters: parameters),
        parent._graphValue(parameters: parameters).with {
          $0.formUnion(.modified)
        },
      ])
  }
}

extension _IfCaseLetReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "IfCaseLet",
      traits: .switchCase
    )
    return .node(
      info,
      children: [
        child._graphValue(parameters: parameters),
        parent._graphValue(parameters: parameters).with {
          $0.formUnion(.modified)
        },
      ])
  }
}

extension _ForEachReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "ForEach",
      traits: .list
    )
    #warning("Quick Recursive fix for now")
    if Parent.State.self == Element.State.self {
      return .node(info, children: [])
    }

    let child = self.element._graphValue(parameters: parameters)
    return .node(
      info,
      children: [
        child,
        parent._graphValue(parameters: parameters).with {
          $0.formUnion(.modified)
        },
      ])
  }
}

extension EmptyReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(Self.self, traits: .empty)
    return .value(info)
  }
}

extension BindingReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(Self.self, traits: .binding)
    return .value(info)
  }
}

extension _SignpostReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "SignPost",
      traits: [.modifier, .debug]
    )
    return .node(
      info,
      children: [
        base._graphValue(parameters: parameters)
      ])
  }
}

extension _PrintChangesReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "PrintChanges",
      traits: [.modifier, .debug]
    )
    return .node(
      info,
      children: [
        base._graphValue(parameters: parameters)
      ])
  }
}

extension _DependencyKeyWritingReducer {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "Dependency",
      traits: .modifier
    )
    return .node(
      info,
      children: [
        base._graphValue(parameters: parameters)
      ])
  }
}

extension CombineReducers {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "Combine",
      traits: .group
    )
    return .node(
      info,
      children: [
        reducers._graphValue(parameters: parameters)
      ])
  }
}

extension Scope {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(Self.self, name: "Scope", traits: .scope)
    return .node(
      info,
      children: [
        child._graphValue(parameters: parameters)
      ])
  }
}

extension Optional {
  public func _graphValue<State, Action>(parameters: ReducerGraphValue.Parameters)
    -> ReducerGraphValue?
  where Wrapped: ReducerProtocol, Wrapped.State == State, Wrapped.Action == Action {
    switch self {
    case .none:
      guard parameters.isExhaustive else { return nil }
      let info = ReducerInfo(
        Wrapped.self,
        name: "\(_typeName(Wrapped.self, qualified: false))?",
        traits: [.optional]
      )
      return .node(info, children: [])
    case .some(let wrapped):
      return wrapped._graphValue(parameters: parameters)
    }
  }
}

extension ReducerBuilder._Optional {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "Optional",
      traits: [.optional, .builder]
    )
    if let wrapped = self.wrapped._graphValue(parameters: parameters) {
      return .node(info, children: [wrapped])
    } else {
      return .value(info)
    }
  }
}

extension ReducerBuilder._Conditional {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "Conditional",
      traits: [.conditional, .builder]
    )
    switch self {
    case let .first(first):
      if parameters.isExhaustive {
        let second = ReducerInfo(Second.self)
        return .node(
          info,
          children: [
            first._graphValue(parameters: parameters),
            .node(second, children: []),
          ])
      } else {
        return .node(info, children: [first._graphValue(parameters: parameters)])
      }
    case let .second(second):
      if parameters.isExhaustive {
        let first = ReducerInfo(First.self)
        return .node(
          info,
          children: [
            .node(first, children: []),
            second._graphValue(parameters: parameters),
          ])
      } else {
        return .node(info, children: [second._graphValue(parameters: parameters)])
      }
    }
  }
}

extension ReducerBuilder._SequenceMany {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "SequenceMany",
      traits: [.builder]
    )
    let children = self.reducers.map { $0._graphValue(parameters: parameters) }
    return .node(info, children: children)
  }
}

extension ReducerBuilder._Sequence {
  public func _graphValue(parameters: ReducerGraphValue.Parameters) -> ReducerGraphValue {
    let info = ReducerInfo(
      Self.self,
      name: "Sequence",
      traits: [.builder, .builderSequence]
    )
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

import Foundation
extension ReducerProtocol {
  public func printGraphValue() {
    //    let _ = DependencyValues.withValue(\.reducerPath, []) {
    print("---")

    let tree = _graphValue(parameters: .init())
    customDump(tree)
    let json = try! JSONEncoder().encode(tree)
    let string = String(decoding: json, as: UTF8.self)
//    print(string, json.count)
    print("***")
    //    }
  }
}
