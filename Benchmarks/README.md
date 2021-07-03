# Benchmarks

To execute the benchmark suite, simply run Benchmarks's tests. To add new benchmarks cases, simply add 
them to `Benchmark` and call them from tests, either using `LocalTCA` or `ReferenceTCA` (or even `Benchmarks` in Debug mode)

- If you just cloned the repository (or cleaned temporary files with `clean.sh`), execute `sh build-all.sh`
- If you edited the benchmarks, execute `sh build-all.sh`
- If you only change the local implementation of TCA, you can execute `sh build-local.sh` only.
- You can remove all intermediary products running `sh clean.sh`. They are already excluded from git in `.gitignore`.
- You can benchmark locally in debug mode if you call cases from `Benchmarks` directly. You don't need to execute build scripts
when you change the local implementation of TCA or the benchmarks.
