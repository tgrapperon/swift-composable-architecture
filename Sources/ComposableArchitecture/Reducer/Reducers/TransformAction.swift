/// A reducer that can transforms the action
public struct TransformAction<Content: ReducerProtocol>: ReducerProtocol {
  public typealias State = Content.State
  public typealias Action = Content.Action
  
  @usableFromInline
  let transform: (Action) -> Action?
  @usableFromInline
  let content: Content
  
  @inlinable
  public init(
    transform: @escaping (Action) -> Action?,
    @ReducerBuilder<State, Action> content: @escaping () -> Content
  ) {
    self.transform = transform
    self.content = content()
  }
  
  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    guard let transformed = transform(action) else { return .none }
    return content.reduce(into: &state, action: transformed)
  }
}

