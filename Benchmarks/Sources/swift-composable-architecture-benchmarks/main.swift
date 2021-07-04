import Benchmark
import ComposableArchitecture
import Benchmarks
import LocalTCA
import ReferenceTCA

benchmark("Reducer-ManyPullbacks-Reference") {
  ReferenceTCA.benchmarkLargePullbacks()
}

benchmark("Reducer-ManyPullbacks-Local") {
  LocalTCA.benchmarkLargePullbacks()
}

benchmark("Reducer-ManyPullbacks-Local-NoXCT") {
  Benchmarks.benchmarkLargePullbacks()
}

Benchmark.main()
