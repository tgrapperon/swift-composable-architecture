import Combine
import Foundation
import SwiftUI
import XCTestDynamicOverlay

/// The ``Effect`` type encapsulates a unit of work that can be run in the outside world, and can
/// feed data back to the ``Store``. It is the perfect place to do side effects, such as network
/// requests, saving/loading from disk, creating timers, interacting with dependencies, and more.
///
/// Effects are returned from reducers so that the ``Store`` can perform the effects after the
/// reducer is done running.
///
/// > Important: ``Store`` is not thread safe, and so all effects must receive values on the same
/// > thread. This is typically the main thread,  **and** if the store is being used to drive UI
/// > then it must receive values on the main thread.
public struct Effect<Output, Failure: Error> {
  let operation: Operation

  enum Operation {
    case none
    case publisher(AnyPublisher<Output, Failure>)
    case run(@Sendable (Send<Output>) async -> Void)
    case merged(
      publishers: [AnyPublisher<Output, Failure>] = [],
      runs: [@Sendable (Send<Output>) async -> Void] = []
    )
  }
}

extension Effect.Operation {
  @inlinable
  func merge(with other: Self) -> Self {
    switch (self, other) {
    case (.none, _): return other
    case (_, .none): return self
    case let (.publisher(p1), .publisher(p2)):
      return .merged(publishers: [p1, p2])
    case let (.run(r1), .publisher(p2)):
      return .merged(publishers: [p2], runs: [r1])
    case let (.merged(publishers: publishers, runs: runs), .publisher(p1)):
      return .merged(publishers: publishers + [p1], runs: runs)
    case let (.publisher(p1), .run(r2)):
      return .merged(publishers: [p1], runs: [r2])
    case let (.run(r1), .run(r2)):
      return .merged(runs: [r1, r2])
    case let (.merged(publishers: publishers, runs: runs), .run(r2)):
      return .merged(publishers: publishers, runs: runs + [r2])
    case let (.publisher(p1), .merged(publishers: publishers, runs: runs)):
      return .merged(publishers: [p1] + publishers, runs: runs)
    case let (.run(r1), .merged(publishers: publishers, runs: runs)):
      return .merged(publishers: publishers, runs: [r1] + runs)
    case let (
      .merged(publishers: publishers1, runs: runs1),
      .merged(publishers: publishers2, runs: runs2)
    ):
      return .merged(publishers: publishers1 + publishers2, runs: runs1 + runs2)
    }
  }
  @inlinable
  func asPublisherAndRun() -> (
    AnyPublisher<Output, Failure>?, (@Sendable (Send<Output>) async -> Void)?
  ) {
    switch self {
    case .none:
      return (nil, nil)
    case let .publisher(p):
      return (p, nil)
    case let .run(r):
      return (nil, r)
    case .merged(let publishers, let runs):
      return (flatten(publishers: publishers), flatten(runs: runs))
    }
  }
  @inlinable
  func flatten(publishers: [AnyPublisher<Output, Failure>]) -> AnyPublisher<Output, Failure>? {
    Publishers.MergeMany(publishers).eraseToAnyPublisher()
  }
  @inlinable
  func flatten(runs: [@Sendable (Send<Output>) async -> Void]) -> (
    @Sendable (Send<Output>) async -> Void
  )? {
    { send in
      await withTaskGroup(of: Void.self) { group in
        for run in runs {
          group.addTask {
            await run(send)
          }
        }
      }
    }
  }
}

// MARK: - Creating Effects

extension Effect {
  /// An effect that does nothing and completes immediately. Useful for situations where you must
  /// return an effect, but you don't need to do anything.
  public static var none: Self {
    Self(operation: .none)
  }
}

extension Effect where Failure == Never {
  /// Wraps an asynchronous unit of work in an effect.
  ///
  /// This function is useful for executing work in an asynchronous context and capturing the result
  /// in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
  ///
  /// For example, if your environment contains a dependency that exposes an `async` function, you
  /// can use ``task(priority:operation:catch:file:fileID:line:)`` to provide an asynchronous
  /// context for invoking that endpoint:
  ///
  /// ```swift
  /// struct FeatureEnvironment {
  ///   var numberFact: (Int) async throws -> String
  /// }
  ///
  /// enum FeatureAction {
  ///   case factButtonTapped
  ///   case faceResponse(TaskResult<String>)
  /// }
  ///
  /// let featureReducer = Reducer<State, Action, Environment> { state, action, environment in
  ///   switch action {
  ///     case .factButtonTapped:
  ///       return .task { [number = state.number] in
  ///         await .factResponse(TaskResult { try await environment.numberFact(number) })
  ///       }
  ///
  ///     case .factResponse(.success(fact)):
  ///       // do something with fact
  ///
  ///     case .factResponse(.failure):
  ///       // handle error
  ///
  ///     ...
  ///   }
  /// }
  /// ```
  ///
  /// The above code sample makes use of ``TaskResult`` in order to automatically bundle the success
  /// or failure of the `numberFact` endpoint into a single type that can be sent in an action.
  ///
  /// The closure provided to ``task(priority:operation:catch:file:fileID:line:)`` is allowed to
  /// throw, but any non-cancellation errors thrown will cause a runtime warning when run in the
  /// simulator or on a device, and will cause a test failure in tests.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - operation: The operation to execute.
  ///   - catch: An error handler, invoked if the operation throws an error other than
  ///     `CancellationError`.
  /// - Returns: An effect wrapping the given asynchronous work.
  public static func task(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> Output,
    catch handler: (@Sendable (Error) async -> Output)? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .run(priority: priority) { send in
      try await send(operation())
    } catch: { error, send in
      guard let handler = handler else {
        #if DEBUG
          var errorDump = ""
          customDump(error, to: &errorDump, indent: 4)
          runtimeWarning(
            """
            An 'Effect.task' returned from "%@:%d" threw an unhandled error:

            %@

            All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
            'Effect.task', or via a 'do' block.
            """,
            [
              "\(fileID)",
              line,
              errorDump,
            ],
            file: file,
            line: line
          )
        #endif
        return
      }
      await send(handler(error))
    }
  }

  /// Wraps an asynchronous unit of work that can emit any number of times in an effect.
  ///
  /// This effect is similar to ``task(priority:operation:catch:file:fileID:line:)`` except it is
  /// capable of emitting 0 or more times, not just once.
  ///
  /// For example, if you had an async stream in your environment:
  ///
  /// ```swift
  /// struct FeatureEnvironment {
  ///   var events: () -> AsyncStream<Event>
  /// }
  /// ```
  ///
  /// Then you could attach to it in a `run` effect by using `for await` and sending each output of
  /// the stream back into the system:
  ///
  /// ```swift
  /// case .startButtonTapped:
  ///   return .run { send in
  ///     for await event in environment.events() {
  ///       send(.event(event))
  ///     }
  ///   }
  /// ```
  ///
  /// See ``Send`` for more information on how to use the `send` argument passed to `run`'s closure.
  ///
  /// The closure provided to ``run(priority:operation:catch:file:fileID:line:)`` is allowed to
  /// throw, but any non-cancellation errors thrown will cause a runtime warning when run in the
  /// simulator or on a device, and will cause a test failure in tests.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - operation: The operation to execute.
  ///   - catch: An error handler, invoked if the operation throws an error other than
  ///     `CancellationError`.
  /// - Returns: An effect wrapping the given asynchronous work.
  public static func run(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable (Send<Output>) async throws -> Void,
    catch handler: (@Sendable (Error, Send<Output>) async -> Void)? = nil,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    return Self(
      operation: .run { send in
        await Task(priority: priority) {
          do {
            try await operation(send)
          } catch is CancellationError {
            return
          } catch {
            guard let handler = handler else {
              #if DEBUG
                var errorDump = ""
                customDump(error, to: &errorDump, indent: 4)
                runtimeWarning(
                  """
                  An 'Effect.run' returned from "%@:%d" threw an unhandled error:

                  %@

                  All non-cancellation errors must be explicitly handled via the 'catch' parameter \
                  on 'Effect.run', or via a 'do' block.
                  """,
                  [
                    "\(fileID)",
                    line,
                    errorDump,
                  ],
                  file: file,
                  line: line
                )
              #endif
              return
            }
            await handler(error, send)
          }
        }
        .cancellableValue
      }
    )
  }

  /// Creates an effect that executes some work in the real world that doesn't need to feed data
  /// back into the store. If an error is thrown, the effect will complete and the error will be
  /// ignored.
  ///
  /// This effect is handy for executing some asynchronous work that your feature doesn't need to
  /// react to. One such example is analytics:
  ///
  /// ```swift
  /// case .buttonTapped:
  ///   return .fireAndForget {
  ///     try await environment.analytics.track("Button Tapped")
  ///   }
  /// ```
  ///
  /// The closure provided to ``fireAndForget(priority:_:)`` is allowed to throw, and any error
  /// thrown will be ignored.
  ///
  /// - Parameters:
  ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
  ///     `Task.currentPriority`.
  ///   - work: A closure encapsulating some work to execute in the real world.
  /// - Returns: An effect.
  public static func fireAndForget(
    priority: TaskPriority? = nil,
    _ work: @escaping @Sendable () async throws -> Void
  ) -> Self {
    .run(priority: priority) { _ in try? await work() }
  }
}

/// A type that can send actions back into the system when used from
/// ``Effect/run(priority:operation:catch:file:fileID:line:)``.
///
/// This type implements [`callAsFunction`][callAsFunction] so that you invoke it as a function
/// rather than calling methods on it:
///
/// ```swift
/// return .run { send in
///   send(.started)
///   defer { send(.finished) }
///   for await event in environment.events {
///     send(.event(event))
///   }
/// }
/// ```
///
/// You can also send actions with animation:
///
/// ```swift
/// send(.started, animation: .spring())
/// defer { send(.finished, animation: .default) }
/// ```
///
/// See ``Effect/run(priority:operation:catch:file:fileID:line:)`` for more information on how to
/// use this value to construct effects that can emit any number of times in an asynchronous
/// context.
///
/// [callAsFunction]: https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID622
@MainActor
public struct Send<Action> {
  public let send: (Action) -> Void

  public init(send: @escaping (Action) -> Void) {
    self.send = send
  }

  /// Sends an action back into the system from an effect.
  ///
  /// - Parameter action: An action.
  public func callAsFunction(_ action: Action) {
    guard !Task.isCancelled else { return }
    self.send(action)
  }

  /// Sends an action back into the system from an effect with animation.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: An animation.
  public func callAsFunction(_ action: Action, animation: Animation?) {
    guard !Task.isCancelled else { return }
    withAnimation(animation) {
      self(action)
    }
  }
}

// MARK: - Composing Effects

extension Effect {
  /// Merges a variadic list of effects together into a single effect, which runs the effects at the
  /// same time.
  ///
  /// - Parameter effects: A list of effects.
  /// - Returns: A new effect
  public static func merge(_ effects: Self...) -> Self {
    .merge(effects)
  }

  /// Merges a sequence of effects together into a single effect, which runs the effects at the same
  /// time.
  ///
  /// - Parameter effects: A sequence of effects.
  /// - Returns: A new effect
  public static func merge<S: Sequence>(_ effects: S) -> Self where S.Element == Effect {
    Publishers.MergeMany(effects).eraseToEffect()
  }

  /// Concatenates a variadic list of effects together into a single effect, which runs the effects
  /// one after the other.
  ///
  /// - Warning: Combine's `Publishers.Concatenate` operator, which this function uses, can leak
  ///   when its suffix is a `Publishers.MergeMany` operator, which is used throughout the
  ///   Composable Architecture in functions like ``Reducer/combine(_:)-1ern2``.
  ///
  ///   Feedback filed: <https://gist.github.com/mbrandonw/611c8352e1bd1c22461bd505e320ab58>
  ///
  /// - Parameter effects: A variadic list of effects.
  /// - Returns: A new effect
  public static func concatenate(_ effects: Self...) -> Self {
    .concatenate(effects)
  }

  /// Concatenates a collection of effects together into a single effect, which runs the effects one
  /// after the other.
  ///
  /// - Warning: Combine's `Publishers.Concatenate` operator, which this function uses, can leak
  ///   when its suffix is a `Publishers.MergeMany` operator, which is used throughout the
  ///   Composable Architecture in functions like ``Reducer/combine(_:)-1ern2``.
  ///
  ///   Feedback filed: <https://gist.github.com/mbrandonw/611c8352e1bd1c22461bd505e320ab58>
  ///
  /// - Parameter effects: A collection of effects.
  /// - Returns: A new effect
  public static func concatenate<C: Collection>(_ effects: C) -> Self where C.Element == Effect {
    effects.isEmpty
      ? .none
      : effects
        .dropFirst()
        .reduce(into: effects[effects.startIndex]) { effects, effect in
          effects = effects.append(effect).eraseToEffect()
        }
  }

  /// Transforms all elements from the upstream effect with a provided closure.
  ///
  /// - Parameter transform: A closure that transforms the upstream effect's output to a new output.
  /// - Returns: A publisher that uses the provided closure to map elements from the upstream effect
  ///   to new elements that it then publishes.
  public func map<T>(_ transform: @escaping (Output) -> T) -> Effect<T, Failure> {
    .init(self.map(transform) as Publishers.Map<Self, T>)
  }
}

// MARK: - Testing Effects

extension Effect {
  /// An effect that causes a test to fail if it runs.
  ///
  /// This effect can provide an additional layer of certainty that a tested code path does not
  /// execute a particular effect.
  ///
  /// For example, let's say we have a very simple counter application, where a user can increment
  /// and decrement a number. The state and actions are simple enough:
  ///
  /// ```swift
  /// struct CounterState: Equatable {
  ///   var count = 0
  /// }
  ///
  /// enum CounterAction: Equatable {
  ///   case decrementButtonTapped
  ///   case incrementButtonTapped
  /// }
  /// ```
  ///
  /// Let's throw in a side effect. If the user attempts to decrement the counter below zero, the
  /// application should refuse and play an alert sound instead.
  ///
  /// We can model playing a sound in the environment with an effect:
  ///
  /// ```swift
  /// struct CounterEnvironment {
  ///   let playAlertSound: () -> Effect<Never, Never>
  /// }
  /// ```
  ///
  /// Now that we've defined the domain, we can describe the logic in a reducer:
  ///
  /// ```swift
  /// let counterReducer = Reducer<
  ///   CounterState, CounterAction, CounterEnvironment
  /// > { state, action, environment in
  ///   switch action {
  ///   case .decrementButtonTapped:
  ///     if state > 0 {
  ///       state.count -= 0
  ///       return .none
  ///     } else {
  ///       return environment.playAlertSound()
  ///         .fireAndForget()
  ///     }
  ///
  ///   case .incrementButtonTapped:
  ///     state.count += 1
  ///     return .none
  ///   }
  /// }
  /// ```
  ///
  /// Let's say we want to write a test for the increment path. We can see in the reducer that it
  /// should never play an alert, so we can configure the environment with an effect that will
  /// fail if it ever executes:
  ///
  /// ```swift
  /// @MainActor
  /// func testIncrement() async {
  ///   let store = TestStore(
  ///     initialState: CounterState(count: 0)
  ///     reducer: counterReducer,
  ///     environment: CounterEnvironment(
  ///       playSound: .unimplemented("playSound")
  ///     )
  ///   )
  ///
  ///   await store.send(.increment) {
  ///     $0.count = 1
  ///   }
  /// }
  /// ```
  ///
  /// By using an `.unimplemented` effect in our environment we have strengthened the assertion and
  /// made the test easier to understand at the same time. We can see, without consulting the
  /// reducer itself, that this particular action should not access this effect.
  ///
  /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
  ///   messages.
  /// - Returns: An effect that causes a test to fail if it runs.
  public static func unimplemented(_ prefix: String) -> Self {
    .fireAndForget {
      XCTFail("\(prefix.isEmpty ? "" : "\(prefix) - ")An unimplemented effect ran.")
    }
  }
}
