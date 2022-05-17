public protocol ReducerModifier<State, Action> {
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

public struct ModifiedContent<Base, Modifier: ReducerModifier> {
  public init(content: Base, modifier: Modifier) {
    self.base = content
    self.modifier = modifier
  }
  
  public var base: Base
  public var modifier: Modifier
}

extension ModifiedContent: ReducerProtocol
where Base: ReducerProtocol,
      Base.State == Modifier.State,
      Base.Action == Modifier.Action
{
  public typealias Body = Self

  public func reduce(into state: inout Modifier.State, action: Modifier.Action) -> Effect<Modifier.Action, Never> {
    let content = _ReducerModifier_Content<Modifier>(content: self.base)
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
extension ModifiedContent: ReducerModifier
where Base: ReducerModifier, Base.State == Modifier.State, Base.Action == Modifier.Action {
  public typealias State = Modifier.State
  public typealias Action = Modifier.Action
  
  // Implementation is inefficient and only their to provide some API.
  public typealias Body = ModifiedContent<ModifiedContent<Content, Base>, Modifier>
  public func body(content: Content) -> ModifiedContent<ModifiedContent<Content, Base>, Modifier> {
    content
      .modifier(base)
      .modifier(modifier)
  }
}

extension ReducerModifier {
  public func concat<Modifier: ReducerModifier>(_ modifier: Modifier) -> ModifiedContent<Self, Modifier> where State == Modifier.State, Action == Modifier.Action {
    ModifiedContent(content: self, modifier: modifier)
  }
}
