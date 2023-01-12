import Charts
import SwiftUI
import Combine
@MainActor
final class MeasureModel: ObservableObject {
  enum Animations: String, CaseIterable, Hashable {
    case none
    case `default`
    case linear
    case easeInOut
    case spring
    
    var animation: Animation? {
      switch self {
      case .none:
        return .none
      case .default:
        return .default
      case .linear:
        return .linear
      case .easeInOut:
        return .easeInOut
      case .spring:
        return .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.3)
      }
    }
  }
  
  
  let label: String
  let range: ClosedRange<CGFloat> = 100...200
  @MainActor
  @Published var measures: [ProgressMeasure] = []
  @MainActor
  @Published var result: String = ""
  
//  var animations: [Animation] = [
//
//    .default,
//    .linear(duration: 1),
//    .easeInOut(duration: 1),
//    .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.3)
//  ]
  var selectedAnimationIndex: Int =  4
  @Published var selectedAnimation: Animations = .default

  var cancellable: AnyCancellable?
  init(label: String) {
    self.label = label
    cancellable = $measures
      .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
      .sink {
        self.result = $0.count.formatted()
    }
  }
  var startInstant: ContinuousClock.Instant?
  func start() {
    measures.removeAll()
    startInstant = nil
  }
  func stop() {}
 @MainActor
  func append(_ dimension: CGFloat, instant: ContinuousClock.Instant) {
    if startInstant == nil {
      startInstant = ContinuousClock().now
    }
    let progress = ProgressMeasure(
      timestamp: startInstant!.duration(to: instant),
      progress: (dimension - range.lowerBound) / (range.upperBound - range.lowerBound)
    )
    measures.append(progress)
  }
}

struct ProgressMeasure: Identifiable, Hashable {
  var id: Duration { timestamp }
  let timestamp: Duration
  var timestampAsDouble: Double {
    Double(timestamp.components.seconds) + Double(timestamp.components.attoseconds) * 1e-18
  }
  let progress: Double
}


struct BindingAnimationTestCase: View {
  @State var isOn: Bool = false
  @ObservedObject var model: MeasureModel = .init(label: "Test")

  var body: some View {
    VStack {
      Text(model.result)
      Chart(model.measures) {
        LineMark(
          x: .value("t", $0.timestampAsDouble),
          y: .value("%", $0.progress)
        )
        .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .foregroundStyle(Color.red)
      }
//      .chartXScale(domain: 0...1)
      .chartYScale(domain: -0.5...1.5)
      .frame(height: 200)
      VStack {
        Picker("Animation", selection: $model.selectedAnimation) {
          ForEach(MeasureModel.Animations.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(.segmented)
        HStack {
          Button("Reset") { model.start() }
            .buttonStyle(.bordered)
          Toggle(
            isOn: $isOn.animation(model.selectedAnimation.animation)
          ) {
            Text("Toggle")
          }.labelsHidden()

          MeasureView {
            model.append($0, instant: $1)
          }
          .opacity(0)
          .frame(width: !isOn ? model.range.lowerBound : model.range.upperBound, height: 20)
          .frame(maxWidth: .infinity, alignment: .leading)

        }
      }.padding(.horizontal)
      ZStack {
        Circle()
          .fill(.red.opacity(0.25))
        Circle()
          .strokeBorder(.red.opacity(0.5), lineWidth: 2)
      }
      .frame(
        width: !isOn ? model.range.lowerBound : model.range.upperBound,
        height: !isOn ? model.range.lowerBound : model.range.upperBound
      )
      .frame(width: model.range.upperBound, height: model.range.upperBound)

    }
  }
}

struct BindingAnimationTestCase_Previews: PreviewProvider {
  static var previews: some View {
    BindingAnimationTestCase()
  }
}

struct MeasureView: UIViewRepresentable {
  let onChange: (CGFloat, ContinuousClock.Instant) -> Void

  func makeUIView(context: Context) -> View {
    View(onChange: onChange)
  }
  func updateUIView(_ uiView: View, context: Context) {
    uiView.onChange = onChange
  }

  final class View: UIView {
    var onChange: (CGFloat, ContinuousClock.Instant) -> Void

    init(
      onChange: @escaping (CGFloat, ContinuousClock.Instant) -> Void
    ) {
      self.onChange = onChange
      super.init(frame: .zero)
      self.backgroundColor = UIColor.red.withAlphaComponent(0.3)
      self.layer.borderColor = UIColor.red.withAlphaComponent(0.8).cgColor
      self.layer.borderWidth = 2
      self.layer.cornerRadius = 6
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override var frame: CGRect {
      didSet {
        DispatchQueue.main.async { [frame, onChange] in
          onChange(frame.width, ContinuousClock().now)
        }
      }
    }
  }
}
