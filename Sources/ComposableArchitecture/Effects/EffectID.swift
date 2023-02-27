import Dependencies

@propertyWrapper
public struct _EffectID<Base>: Hashable, Sendable {
  let navigationID: NavigationID
  fileprivate let identifier: AnyHashableSendable?
  
  public init(
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) {
    @Dependency(\.navigationID) var navigationID: NavigationID
    self.navigationID = navigationID
    self.identifier = .init(file: file, line: line, column: column)
  }

  public init<ID: Hashable & Sendable>(
    _ id: ID
  ) {
    @Dependency(\.navigationID) var navigationID: NavigationID
    self.navigationID = navigationID
    self.identifier = .init(id)
  }

  public var wrappedValue: Self {
    self
  }
}

public typealias EffectOf<R: ReducerProtocol> = _EffectID<R>

extension ReducerProtocol {
  public typealias EffectID = _EffectID<Self>
}

private struct AnyHashableSendable: Hashable, @unchecked Sendable {
  let base: AnyHashable

  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }

  init(file: StaticString, line: UInt, column: UInt) {
    self.base = ["\(file)", line, column] as [AnyHashable]
  }
}
