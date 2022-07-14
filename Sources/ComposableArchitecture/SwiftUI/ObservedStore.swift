import SwiftUI

public protocol ViewStateProtocol: Equatable {
  associatedtype State
  init(state: State)
}

public protocol ViewActionProtocol {
  associatedtype Action
  static var embed: (Self) -> Action { get }
}

@propertyWrapper
public struct ObservedStore<StoreState, StoreAction>: DynamicProperty {
  @ObservedObject var viewStore: ViewStore<StoreState, StoreAction>
  public init(wrappedValue: Store<StoreState, StoreAction>) where StoreState: Equatable {
    self.wrappedValue = wrappedValue
    self.viewStore = ViewStore(wrappedValue)
  }
  public var wrappedValue: Store<StoreState, StoreAction>
  public var projectedValue: ViewStore<StoreState, StoreAction> { viewStore }
}

extension ObservedStore {
  @propertyWrapper
  public struct Of<ViewState: ViewStateProtocol>: DynamicProperty
  where ViewState.State == StoreState {
    @ObservedObject var viewStore: ViewStore<ViewState, StoreAction>

    public init(wrappedValue: Store<StoreState, StoreAction>) {
      self.wrappedValue = wrappedValue
      self.viewStore = ViewStore(wrappedValue.scope(state: ViewState.init(state:)))
    }
    public var wrappedValue: Store<StoreState, StoreAction>
    public var projectedValue: ViewStore<ViewState, StoreAction> { viewStore }
  }
}

extension ObservedStore {
  @propertyWrapper
  public struct ViewAction<ViewAction: ViewActionProtocol>: DynamicProperty
  where ViewAction.Action == StoreAction, StoreState: Equatable {
    @ObservedObject var viewStore: ViewStore<StoreState, ViewAction>

    public init(wrappedValue: Store<StoreState, StoreAction>) {
      self.wrappedValue = wrappedValue
      self.viewStore = ViewStore(wrappedValue.scope(state: { $0 }, action: ViewAction.embed))
    }
    public var wrappedValue: Store<StoreState, StoreAction>
    public var projectedValue: ViewStore<StoreState, ViewAction> { viewStore }
  }
}

extension ObservedStore.Of {
  @propertyWrapper
  public struct And<ViewAction: ViewActionProtocol>: DynamicProperty
  where ViewAction.Action == StoreAction {
    @ObservedObject var viewStore: ViewStore<ViewState, ViewAction>

    public init(wrappedValue: Store<StoreState, StoreAction>) {
      self.wrappedValue = wrappedValue
      self.viewStore = ViewStore(
        wrappedValue.scope(state: ViewState.init(state:), action: ViewAction.embed))
    }
    public var wrappedValue: Store<StoreState, StoreAction>
    public var projectedValue: ViewStore<ViewState, ViewAction> { viewStore }
  }
}
