import Foundation
extension DependencyValues {
  var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }

  private enum NavigationIDKey: LiveDependencyKey {
    static let liveValue = NavigationID.live
    static let testValue = NavigationID.live
  }
}

// TODO: Fix Sendability
public struct NavigationID: @unchecked Sendable {
  public var current: AnyHashable?
  public var next: @Sendable () -> AnyHashable

  public static let live = Self { UUID() }
  public static var incrementing: Self {
    let next = _next()
    return Self { next() }
  }
}

func _next() -> () -> AnyHashable {
  var count = 1
  return {
    defer { count += 1 }
    return count
  }
}
