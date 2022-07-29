import IdentifiedCollections
import OrderedCollections
import SwiftUI

/// A type from which we can extract or embed a value keyed by some Index/Id/Key
public protocol LazyIdentifiedConversion {
  associatedtype ID: Hashable
  associatedtype Source
  associatedtype Destination

  func extract(source: Source, id: ID) -> Destination?
  func embed(source: inout Source, id: ID, destination: Destination?)
}

/// Same as LazyIdentifiedConversion, but is able to provide a list of `ID`s
public protocol LazyIdentifiedCollectionConversion: LazyIdentifiedConversion {
  associatedtype IDs: Collection & Equatable where IDs.Element == ID
  func ids(source: Source) -> IDs
}

/// Describe a lazy conversion/derivation from a source to an `IdentifiedArray`'s `Element`
public struct LazyIdentifiedArrayConversion<Source, ID: Hashable, Element>:
  LazyIdentifiedCollectionConversion
{
  let keyPath: WritableKeyPath<Source, IdentifiedArray<ID, Element>>
  let updateElement: (Source, ID, inout Element) -> Void

  /// - Parameters:
  ///   - keyPath: A `KeyPath` from `Source` to the `IdentifiedArray`
  ///   - updateElement: A closure where one can update the `element` at `id` using `source`.
  public init(
    _ keyPath: WritableKeyPath<Source, IdentifiedArray<ID, Element>>,
    updateElement: @escaping (Source, ID, inout Element) -> Void = { _, _, _ in () }
  ) {
    self.keyPath = keyPath
    self.updateElement = updateElement
  }

  public func ids(source: Source) -> OrderedSet<ID> {
    source[keyPath: keyPath].ids
  }

  public func extract(source: Source, id: ID) -> Element? {
    guard var element = source[keyPath: keyPath][id: id] else { return nil }
    self.updateElement(source, id, &element)
    return element
  }

  public func embed(source: inout Source, id: ID, destination: Element?) {
    guard let element = destination else { return }
    source[keyPath: keyPath][id: id] = element
  }
}

/// Describe a lazy conversion/derivation from a source to an `Dictionary`'s `Value`
public struct LazyDictionaryConversion<Source, Key: Hashable, Value>:
  LazyIdentifiedCollectionConversion
{
  let keyPath: WritableKeyPath<Source, [Key: Value]>
  let updateValue: (Source, ID, inout Value) -> Void

  public init(
    _ keyPath: WritableKeyPath<Source, [Key: Value]>,
    updateValue: @escaping (Source, Key, inout Value) -> Void = { _, _, _ in () }
  ) {
    self.keyPath = keyPath
    self.updateValue = updateValue
  }

  public func ids(source: Source) -> Dictionary<Key, Value>.Keys {
    source[keyPath: keyPath].keys
  }

  public func extract(source: Source, id: Key) -> Value? {
    guard var element = source[keyPath: keyPath][id] else { return nil }
    self.updateValue(source, id, &element)
    return element
  }

  public func embed(source: inout Source, id: Key, destination: Value?) {
    guard let element = destination else { return }
    source[keyPath: keyPath][id] = element
  }
}

extension Reducer {
  /// This generalize `forEach` pullbacks, using a `LazyIdentifiedConversion` to extract and
  /// reinsert elements in a lazy way.
  public func forEachLazy<
    LazyConversion: LazyIdentifiedConversion, GlobalState, GlobalAction, GlobalEnvironment
  >(
    state: @escaping (GlobalState) -> LazyConversion,
    action toLocalAction: CasePath<GlobalAction, (LazyConversion.ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where LazyConversion.Source == GlobalState, LazyConversion.Destination == State {
    .init { globalState, globalAction, globalEnvironment in
      guard let (id, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
      let conversion = state(globalState)
      guard var localState = conversion.extract(source: globalState, id: id) else {
        //        runtimeWarning(
        //          """
        //          A "forEachLazy" reducer at "%@:%d" received an action when state contained no element \
        //          with that id. …
        //
        //            Action:
        //              %@
        //            ID:
        //              %@
        //
        //          This is generally considered an application logic error, and can happen for a few \
        //          reasons:
        //
        //          • This "forEachLazy" reducer was combined with or run from another reducer that removed \
        //          the element at this id when it handled this action. To fix this make sure that this \
        //          "forEachLazy" reducer is run before any other reducers that can move or remove elements \
        //          from state. This ensures that "forEachLazy" reducers can handle their actions for the \
        //          element at the intended id.
        //
        //          • An in-flight effect emitted this action while state contained no element at this id. \
        //          It may be perfectly reasonable to ignore this action, but you also may want to cancel \
        //          the effect it originated from when removing an element from the identified array, \
        //          especially if it is a long-living effect.
        //
        //          • This action was sent to the store while its state contained no element at this id. \
        //          To fix this make sure that actions for this reducer can only be sent to a view store \
        //          when its state contains an element at this id. In SwiftUI applications, use \
        //          "ForEachLazyStore".
        //          """,
        //          [
        //            "\(file)",
        //            line,
        //            debugCaseOutput(localAction),
        //            "\(id)",
        //          ]
        //        )
        return .none
      }
      let effects =
        self
        .run(
          &localState,
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((id, $0)) }
      conversion.embed(source: &globalState, id: id, destination: localState)
      return effects
    }
  }
}

/// Same as `ForEach` store, but using a lazy conversion. For this reason, the source is a `store`
/// that is not already scoped.
public struct ForEachLazyStore<
  LazyConversion: LazyIdentifiedCollectionConversion,
  State, Action,
  EachState, EachAction, Data: Collection, Content: View
>: DynamicViewContent
where State == LazyConversion.Source, EachState == LazyConversion.Destination {
  public typealias ID = LazyConversion.ID
  public typealias IDs = LazyConversion.IDs
  public let data: Data
  let content: () -> Content

  public init<EachContent>(
    _ store: Store<State, Action>,
    state: @escaping (State) -> LazyConversion,
    action: @escaping (ID, EachAction) -> (Action),
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == LazyMapSequence<LazySequence<IDs>.Elements, EachState?>,
    Content == WithViewStore<IDs, Action, ForEach<IDs, ID, EachContent>>
  {
    let source = ViewStore(store, removeDuplicates: { _, _ in true }).state
    let conversion = state(source)
    self.data = conversion.ids(source: source).lazy.map {
      conversion.extract(source: source, id: $0)
    }
    self.content = {
      WithViewStore(store.scope(state: conversion.ids(source:))) { viewStore in
        ForEach(viewStore.state, id: \.self) { id -> EachContent in
          // NB: We cache elements here to avoid a potential crash where SwiftUI may re-evaluate
          //     views for elements no longer in the collection.
          //
          // Feedback filed: https://gist.github.com/stephencelis/cdf85ae8dab437adc998fb0204ed9a6b
          let source = ViewStore(store, removeDuplicates: { _, _ in true }).state
          var element = conversion.extract(source: source, id: id)!
          return content(
            store.scope(
              state: {
                element = conversion.extract(source: $0, id: id) ?? element
                return element
              },
              action: { action(id, $0) }
            )
          )
        }
      }
    }
  }

  public var body: some View {
    self.content()
  }
}
