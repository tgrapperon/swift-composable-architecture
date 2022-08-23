import Dependencies

@propertyWrapper
public struct DependencyState<Value>: DependencyKey {
  public typealias Value = Value?
  public static var liveValue: Value? { nil }

  // Public because of @_transparent
  public let defaultValue: Value?
  public let file: StaticString
  public let line: UInt
  public let column: UInt

  @_transparent
  public var wrappedValue: Value {
    guard let value = DependencyValues.current[Self.self] ?? defaultValue
    else {
      fatalError(
        """
        Trying to extract an undefined \(Value.self) DependencyState in \(file) at line \(line).

        Please check that this value is defined in some parent reducer using \
        `.dependencyState((State) -> Value)`, or provide a default at the property wrapper's \
        level: `@DependencyState(default: …) var value`.
        "
        """
      )
    }
    return value
  }

  public init(
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.defaultValue = nil
    self.file = file
    self.line = line
    self.column = column
  }

  public init(
    default: Value,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.defaultValue = `default`
    self.file = file
    self.line = line
    self.column = column
  }
}

extension ReducerProtocol {
  public func dependencyState<Value>(_ value: @escaping (State) -> Value)
  -> _Observe<_DependencyKeyWritingReducer<Self>
  > {
    _Observe { state, _ in
      self.dependencies {
        $0[DependencyState<Value>.self] = value(state)
      }
    }
  }
}
