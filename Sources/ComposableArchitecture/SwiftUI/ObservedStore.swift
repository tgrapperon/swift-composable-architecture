import SwiftUI

public protocol ViewStateProtocol: Equatable {
  associatedtype State
  init(state: State)
}

@dynamicMemberLookup
public struct IdentityViewScope<State>: ViewStateProtocol where State: Equatable {
  let state: State
  public init(state: State) { self.state = state }
  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    state[keyPath: keyPath]
  }
}

public typealias ObservedStore<State, Action> = ViewScope<IdentityViewScope<State>>
  .ObservedStore<Action> where State: Equatable

public enum ViewScope<V: ViewStateProtocol> {}

extension ViewScope {
  @propertyWrapper
  public struct ObservedStore<Action>: DynamicProperty {
    @ObservedObject var viewStore: ViewStore<V, Action>
    
    public init(wrappedValue: Store<V.State, Action>) {
      self.wrappedValue = wrappedValue
      self.viewStore = ViewStore(wrappedValue.scope(state: V.init(state:)))
    }
    public var wrappedValue: Store<V.State, Action>
    public var projectedValue: ViewStore<V, Action> { viewStore }
  }
}
