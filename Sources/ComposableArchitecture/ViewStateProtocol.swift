import SwiftUI

public protocol ViewStateProtocol {
  associatedtype State
  init(_ state: State)
  init(state: State)
}

extension ViewStateProtocol {
  public init(_ state: State) {
    self.init(state: state)
  }
  public init(state: State) {
    self.init(state)
  }
}

enum WithTaskLocalState {
  @TaskLocal static var state: Any?

  static func `in`<State, Result>(_ operation: @escaping (State) -> Result) -> (State) -> Result {
    if (Result.self as Any) is any ViewStateProtocol.Type {
      return { state in
        WithTaskLocalState.$state.withValue(state) {
          operation(state)
        }
      }
    }
    return operation
  }
}

@propertyWrapper
public struct ObservedValue<State, Value> {
  var value: Value?
  public var wrappedValue: Value {
    value!
  }
  public init(_ transform: (State) -> Value) {
    if let localState = WithTaskLocalState.state as? State {
      self.value = transform(localState)
    }
  }
  public init(_ keyPath: KeyPath<State, Value>) {
    if let localState = WithTaskLocalState.state as? State {
      self.value = localState[keyPath: keyPath]
    }
  }
}

@propertyWrapper
public struct ObservedBindableValue<State, Value> {
  var value: Value?
  let keyPath: WritableKeyPath<State, BindableState<Value>>
  public var wrappedValue: Value {
    value!
  }
  public var projectedValue: Self { self }
  public init(_ keyPath: WritableKeyPath<State, BindableState<Value>>) {
    if let localState = WithTaskLocalState.state as? State {
      self.value = localState[keyPath: keyPath].wrappedValue
    }
    self.keyPath = keyPath
  }
}

extension ObservedValue: Equatable where Value: Equatable {}
extension ObservedBindableValue: Equatable where Value: Equatable {}

extension ViewStateProtocol {
  public typealias Observe<Value> = ObservedValue<State, Value>
  public typealias Bind<Value> = ObservedBindableValue<State, Value>
}

extension ViewStore {

}
