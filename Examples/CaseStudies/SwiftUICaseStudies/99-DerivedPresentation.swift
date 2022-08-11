@preconcurrency import ComposableArchitecture
import SwiftUI

enum DerivedTimerStateKey: LiveDependencyKey {
  static var testValue: AsyncSharedStream<DerivedTimer.State> = .init()
  static var liveValue: AsyncSharedStream<DerivedTimer.State> = .init()
}

enum CurrentValueKey: LiveDependencyKey {
  static var testValue: AsyncSharedStream<TimeInterval> = .init()
  static var liveValue: AsyncSharedStream<TimeInterval> = .init()
}

extension DependencyValues {
  var rootState: AsyncSharedStream<DerivedTimer.State> {
    get { self[DerivedTimerStateKey.self] }
    set { self[DerivedTimerStateKey.self] = newValue }
  }

  var currentValue: AsyncSharedStream<TimeInterval> {
    get { self[CurrentValueKey.self] }
    set { self[CurrentValueKey.self] = newValue }
  }
}

// Root domain
struct DerivedTimer: ReducerProtocol {
  struct State: Equatable {
    var currentValue: TimeInterval = 0
    var timeInterval: TimeInterval = 0.7

    // Embed and sync the child domain
    private var _button = TimerEditorButton.State()
    var button: TimerEditorButton.State {
      get {
        var state = _button
        state.currentValue = currentValue
        state.timeInterval = timeInterval
        return state
      }
      set {
        _button = newValue
        currentValue = newValue.currentValue
        timeInterval = newValue.timeInterval
      }
    }
  }

  enum Action: Equatable, Sendable {
    case button(TimerEditorButton.Action)
    case cancel
    case tick
  }

  enum CancellationID {}
  @Dependency(\.rootState) var rootState

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.button, action: /Action.button) {
      TimerEditorButton()
    }
    .bindStreamDependency(\.rootState, to: \.currentValue, transform: \.currentValue)

    Reduce { state, action in
      switch action {
      case .button:
        return .none
      case .cancel:
        return .cancel(id: CancellationID.self)
      case .tick:
        let timeInterval = state.timeInterval
        // This is off by one `timerInterval`, but that's not the point.
        // This is an effect that happens in the parent of the parent.
        // The presenting/presented feature are not aware of it.
        state.currentValue += state.timeInterval
        return .merge(
          .task {
            try? await Task.sleep(nanoseconds: UInt64(Double(NSEC_PER_SEC) * timeInterval))
            return .tick
          }.cancellable(id: CancellationID.self),
          .fireAndForget { [state] in // Update the dependency
            await rootState.send(state)
          }
        )
      }
    }
  }
}

// Intermediary domain
struct TimerEditorButton: ReducerProtocol {
  struct State: Equatable, Sendable {
    var currentValue: TimeInterval = 0
    var timeInterval: TimeInterval = 0.5

    // Three examples, one direct (disfunctional),
    // one through the `SyncEditor` "container",
    // and one using a computed wrapper.

    // --- Direct
    @PresentationStateOf<TimerEditor> var editor

    // --- Synchronized via its own "domain"
    struct SyncEditor: Equatable {
      @PresentationStateOf<TimerEditor> var editor
    }
    var _syncEditor: SyncEditor = .init()
    var syncEditor: SyncEditor {
      get {
        var state = _syncEditor
        state.editor?.currentValue = currentValue
        state.editor?.timeInterval = timeInterval
        return state
      }
      set {
        _syncEditor = newValue
        if let editor = newValue.editor {
          currentValue = editor.currentValue
          timeInterval = editor.timeInterval
        }
      }
    }

    // --- Computed property approach
    @PresentationStateOf<TimerEditor> fileprivate var presentedEditor_
    var presentedEditor: PresentationStateOf<TimerEditor> {
      get {
        var state = $presentedEditor_
        state.wrappedValue?.currentValue = currentValue
        state.wrappedValue?.timeInterval = timeInterval
        return state
      }
      set {
        $presentedEditor_ = newValue
        if let editor = newValue.wrappedValue {
          currentValue = editor.currentValue
          timeInterval = editor.timeInterval
        }
      }
    }
  }

  // Ids for presentation
  static let editor: AnyHashable = "Editor"
  static let syncEditor: AnyHashable = "SyncEditor"
  static let computedWrapper: AnyHashable = "ComputedWrapper"

  enum Action: Equatable, Sendable {
    // We can share the same action!
    case editor(PresentationActionOf<TimerEditor>)
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      // Merely presented state creation
      case .editor(.present(id: Self.editor, _)):
        state.editor = .init(currentValue: state.currentValue, timeInterval: state.timeInterval)
        return .none

      case .editor(.present(id: Self.syncEditor, _)):
        state._syncEditor = .init(
          editor: .presented(
            id: Self.syncEditor,  // ? or nothing?
            .init(currentValue: state.currentValue, timeInterval: state.timeInterval))
        )
        return .none

      case .editor(.present(id: Self.computedWrapper, _)):
        state.presentedEditor_ = .init(
          currentValue: state.currentValue, timeInterval: state.timeInterval)
        return .none

      case .editor(.presented):
        // We should propagate upstream changes from the direct case here.
        // I don't know how to filter changes originating only from this
        // presentation without creating a new action, so I discriminate using
        // the state.
        // That won't solve the fact that it doesn't update its own state
        // when this parent state changes.
        if let editor = state.editor {
          state.timeInterval = editor.timeInterval
        }
        return .none
      case .editor:
        return .none
      }
    }
    .presentationDestination(state: \.$editor, action: /Action.editor) {
      TimerEditor()
    }
    .presentationDestination(state: \.syncEditor.$editor, action: /Action.editor) {
      TimerEditor()
    }
    .presentationDestination(state: \.presentedEditor, action: /Action.editor) {
      TimerEditor()
    }
  }
}

// Presented domain
struct TimerEditor: ReducerProtocol {
  struct State: Equatable, Sendable {
    var currentValue: TimeInterval
    var timeInterval: TimeInterval
  }

  enum Action: Equatable, Sendable {
    case currentValue(TimeInterval)
    case timeInterval(TimeInterval)
    case task
  }

  @Dependency(\.currentValue) var currentValues

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case let .currentValue(timeInterval):
        state.currentValue = timeInterval
        return .none
      case .task:
        return .run { send in
          for await currentValue in self.currentValues {
            await send(.currentValue(currentValue))
          }
        }
      case let .timeInterval(timeInterval):
        state.timeInterval = timeInterval
        return .none
      }
    }
  }
}

// MARK: - Views

struct DerivedTimerView: View {
  let store: StoreOf<DerivedTimer>

  var body: some View {
    WithViewStore(store) { viewStore in
      VStack {
        Spacer()
        Text("\(format(viewStore.currentValue)) by \(format(viewStore.timeInterval))")
          .font(.largeTitle)
        Spacer()
        TimerEditorButtonView(
          store: store.scope(state: \.button, action: DerivedTimer.Action.button)
        )
      }
      .onAppear {
        viewStore.send(.tick)
      }
      .onDisappear {
        viewStore.send(.cancel)
      }
    }
    .monospacedDigit()
  }
}

struct TimerEditorButtonView: View {
  let store: StoreOf<TimerEditorButton>

  var body: some View {
    WithViewStore(store) { viewStore in
      VStack {
        Button {
          viewStore.send(
            .editor(.present(id: TimerEditorButton.editor)))
        } label: {
          VStack {
            Text("\(format(viewStore.currentValue)) by \(format(viewStore.timeInterval))")
          }
        }
        Button {
          viewStore.send(
            .editor(.present(id: TimerEditorButton.syncEditor)))
        } label: {
          VStack {
            Text("Sync \(format(viewStore.currentValue)) by \(format(viewStore.timeInterval))")
          }
        }
        Button {
          viewStore.send(
            .editor(.present(id: TimerEditorButton.computedWrapper)))
        } label: {
          VStack {
            Text("Wrapper \(format(viewStore.currentValue)) by \(format(viewStore.timeInterval))")
          }
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .sheet(store: store.scope(state: \.$editor, action: TimerEditorButton.Action.editor)) { store in
      TimerEditorView(store: store)
        .padding()
        .presentationDetents([.fraction(0.2)])
    }
    .sheet(store: store.scope(state: \.syncEditor.$editor, action: TimerEditorButton.Action.editor))
    { store in
      TimerEditorView(store: store)
        .padding()
        .presentationDetents([.fraction(0.2)])
    }
    .sheet(store: store.scope(state: \.presentedEditor, action: TimerEditorButton.Action.editor)) {
      store in
      TimerEditorView(store: store)
        .padding()
        .presentationDetents([.fraction(0.2)])
    }
  }
  func format(_ timeInterval: Double) -> String {
    timeInterval.formatted(.number.precision(.fractionLength(1)))
  }
}

struct TimerEditorView: View {
  let store: StoreOf<TimerEditor>

  var body: some View {
    WithViewStore(store) { viewStore in
      VStack {
        Text(format(viewStore.currentValue))
        Stepper(
          "Interval: \(format(viewStore.timeInterval))",
          value: viewStore.binding(
            get: \.timeInterval,
            send: TimerEditor.Action.timeInterval
          ),
          step: 0.1)
      }
      .task {
        await viewStore.send(.task).finish()
      }
    }.monospacedDigit()
  }
}

private func format(_ timeInterval: Double) -> String {
  timeInterval.formatted(.number.precision(.fractionLength(1)))
}

struct DerivedTimer_Previews: PreviewProvider {

  static var previews: some View {
    DerivedTimerView(
      store: .init(initialState: .init(), reducer: DerivedTimer())
    )
    TimerEditorButtonView(
      store: .init(initialState: .init(), reducer: TimerEditorButton())
    )
    TimerEditorView(
      store:
        .init(
          initialState: .init(
            currentValue: 127,
            timeInterval: 0.5
          ), reducer: TimerEditor()
        )
    )
  }
}
