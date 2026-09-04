# Fork topology and upstream tracking

`fmdb/essentia` is a fork of **[wo80/essentia](https://github.com/wo80/essentia)**, tracking its **`cmake`** branch.

It is *not* a fork of [MTG/essentia](https://github.com/MTG/essentia) in any practical sense. GitHub reports MTG as the network root, and that is misleading: MTG builds with waf and has **no CMake path at all**. The entire CMake build system this fork depends on — `CMakeLists.txt`, `cmake/modules/`, `packaging/build-dependencies-msvc.bat` — exists only on wo80's `cmake` branch.

**Upstream is `wo80/essentia`, branch `cmake`. Nothing is taken from `MTG/essentia@master` directly.** MTG's work reaches this fork only indirectly, when wo80 syncs his own `master` and merges forward.

## Why this document exists

On **2026-02-02** wo80 relaxed and then removed the Eigen3 version check in `2c9d9e6` and `a70cb36`.

On **2026-02-05** — three days later — the same problem was solved independently here, twice, in `9371de9` and `d77a465`. A third variant, `cad9172b`, existed only in a local working copy and was never pushed.

Three fixes for a problem upstream had already fixed. All three were dropped when this fork was rebased onto upstream, because upstream's version was strictly better: it removed the version bound entirely, where the local attempts kept narrowing it (`3.3...5.99`, `3.3...6.0`).

The cost was not the diff. It was the guaranteed rebase conflict and the hour spent proving the three commits were redundant. **Check `wo80/essentia@cmake` before fixing a build problem.**

## Branch mapping

| Branch | Role |
| --- | --- |
| `cmake` | The working branch and repository default. Tracks `wo80/essentia@cmake`. All fork work happens here. |
| `cmake-python` | Mirror of wo80's Python variant. **Not maintained** — 27 commits behind wo80 as of 2026-09-01, and never built or tested here. |
| `master` | Stale mirror of MTG, last synced 2025-04-22 and 76 commits behind. Kept only so a merge base against MTG exists. **Do not branch from it.** |

Remotes to configure:

```bash
git remote add wo80     https://github.com/wo80/essentia    # the real upstream
git remote add upstream https://github.com/MTG/essentia     # reference only
```

## Rebase policy

**Rebase `cmake` onto `wo80/essentia@cmake`. Never merge.** Merging buries fork-specific commits inside upstream history and makes the delta unreadable within a release or two. The fork's commits stay at the tip, where `git log wo80/cmake..cmake` always answers "what is ours?".

**Drop a fork commit when upstream has solved the same problem**, even when the two solutions differ — unless ours is demonstrably better, in which case it should be upstreamed rather than carried.

**Prefer upstreaming over carrying.** Every locally-carried change is a change that must survive every future rebase.

**This repository is public. Keep internal references out of it.** No issue-tracker IDs, internal URLs, or ticket footers in commit messages, branch names, or pull request descriptions — they leak into a repository that is world-readable and, once pushed, cannot be fully retracted: GitHub keeps serving orphaned commits by SHA after a force-push, and a merged pull request's head branch name is permanent. Describe *what* changed and *why*; track the *who asked* elsewhere.

The procedure:

```bash
git fetch wo80
git rebase -i --onto wo80/cmake $(git merge-base cmake wo80/cmake) cmake
# drop commits whose problem upstream already fixed
# then verify before force-pushing:
gh workflow run "Build with CMake" --ref <branch>   # all six legs must be green
git push --force-with-lease origin <branch>:cmake
```

CI must be green **before** the force-push, not after. `cmake` is the default branch; a red rebase landing there blocks everyone.

## What is intentionally fork-specific

The delta sits on top of `wo80/essentia@cmake`. List it with:

```bash
git log --oneline wo80/cmake..cmake
```

Deliberately no commit count here: any count written into this file is wrong the moment the commit writing it lands. The categories below are the stable part; the command above is the current answer.

**CI workflow** — `.github/workflows/build-cmake.yml` (8 commits). Fork-specific and staying that way. It builds a six-leg matrix (Linux/macOS/Windows × `USE_TENSORFLOW` ON/OFF) in Release, because `USE_TENSORFLOW=OFF` is what the FMDB desktop app ships and upstream does not exercise it. Upstream's CI serves upstream's needs.

**Dependency search paths** — `cmake/modules/FindTensorFlow.cmake`, plus a `PATHS` block in `FindYAML.cmake` covering `/opt/homebrew` and the Debian multiarch library directories. Fork-specific for now; tied to how this project installs libtensorflow in CI. Revisit if upstream's discovery improves.

**Optional-dependency guards** — `src/algorithms/standard/CMakeLists.txt` (2 commits). **Upstream candidates.** `resample` was compiled without libsamplerate, and the vDSP FFT sources were gated on `ESSENTIA_USE_ACCEL`, a variable set nowhere. Neither is FMDB-specific.

**Example placeholder** — `src/examples/streaming_tensorflowpredict.cpp` (1 commit). Trivial; upstream candidate.

**ML preprocessing decoupling** — `USE_ML_PREPROCESSING` across the root `CMakeLists.txt`, `src/CMakeLists.txt`, `src/algorithms/spectral/CMakeLists.txt` and the generated registry (1 commit). **Upstream candidate.** The four `TensorflowInput*` algorithms compute log-compressed mel bands and have no TensorFlow dependency, yet CMake gated them on `USE_TENSORFLOW`, so a TensorFlow-less build shipped without the preprocessing stage its models need. waf never had this problem: its algorithm-ignore list names only `TensorflowPredict*`, `PitchCREPE` and `TempoCNN`. This aligns CMake with waf rather than adding fork-specific behavior.

### Upstreamed

| PR | Change | Outcome |
| --- | --- | --- |
| [wo80/essentia#10](https://github.com/wo80/essentia/pull/10) | `find_package(Yaml)` → `YAML` at the call site, and the same inside `FindYAML.cmake`. The module file is `FindYAML.cmake`, so on a case-sensitive file system it was never loaded and YAML support was silently disabled | merged 2026-09-03 |
| [wo80/essentia#11](https://github.com/wo80/essentia/pull/11) | Quote the value expansion in `essentia_check_set`; a list value clobbers a caller-scope variable, an empty value fails configure | merged 2026-09-03 |

Both landed, and the corresponding fork commit was dropped on the next rebase — the delta shrank rather than growing. This is the intended shape: a fix that belongs upstream goes upstream, and the fork stops carrying it.

Note that #11 fixed a bug in upstream's own code that this fork never had. Reading upstream's diff during a rebase is worth the time.

## Known local-only workaround

`#undef PC` before `#include <Accelerate/Accelerate.h>` in `ffta.h`, `fftacomplex.h`, `iffta.h`, `ifftacomplex.h`.

`src/essentia/streaming/algorithms/poolstorage.h:164` defines `#define PC essentia::streaming::PoolConnector`. Accelerate reaches CarbonCore's `MachineExceptions.h`, whose `MachineInformationPowerPC` struct has a field named `PC`, and the macro rewrites Apple's field declaration.

This is containment, not a fix. The real fix — `poolstorage.h` not putting a two-letter macro in a public header — is a wider change and belongs upstream. Do not send the `#undef` upstream as-is.
