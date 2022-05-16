public protocol ReducerModifier {
  associatedtype State
  associatedtype Action
  
  associatedtype Body: ReducerProtocol<State, Action>
  typealias Content = _ReducerModifier_Content<Self>
  @ReducerBuilder<State, Action>
  func body(content: Content) -> Body
  
}

public struct IdentityModifier<State, Action>: ReducerModifier {
  public func body(content: Content) -> some ReducerProtocol<State, Action> {
    content
  }
}

public struct _ReducerModifier_Content<Modifier: ReducerModifier>: ReducerProtocol {
  public typealias State = Modifier.State
  public typealias Action = Modifier.Action
  public var body: some ReducerProtocol {
    NeverReducer<Modifier.State, Modifier.Action>()
  }
  
  init<Content: ReducerProtocol<Modifier.State, Modifier.Action>>(content: Content) {
    self._reduce = content.reduce(into:action:)
  }
  
  let _reduce: (inout Modifier.Content.State, Modifier.Content.Action) -> Effect<Modifier.Content.Action, Never>
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    _reduce(&state, action)
  }
}

public struct ModifiedContent<Content, Modifier: ReducerModifier> {
  public init(content: Content, modifier: Modifier) {
    self.content = content
    self.modifier = modifier
  }
  
  public var content: Content
  public var modifier: Modifier
}

extension ModifiedContent: ReducerProtocol
where Content: ReducerProtocol,
      Content.State == Modifier.State,
      Content.Action == Modifier.Action
{
  public typealias Body = Self

  public func reduce(into state: inout Modifier.State, action: Modifier.Action) -> Effect<Modifier.Action, Never> {
    let content = _ReducerModifier_Content<Modifier>(content: self.content)
    let modified = modifier.body(content: content)
    return modified.reduce(into: &state, action: action)
  }
}

extension ReducerProtocol {
  public func modifier<Modifier: ReducerModifier>(_ modifier: Modifier) -> ModifiedContent<Self, Modifier> where State == Modifier.State, Action == Modifier.Action {
    ModifiedContent(content: self, modifier: modifier)
  }
}

// I can't make modifier concatenation to build yet
//extension ModifiedContent: ReducerModifier
//where Content: ReducerModifier, Content.State == Modifier.State, Content.Action == Modifier.Action {
//
//  public func body(content: Content) -> some ReducerProtocol {
//    self.modifier.body(content: self.content.body(content: .init(content: content)))
//  }
//}
