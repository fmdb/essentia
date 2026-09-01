# Fork topology and upstream tracking

`fmdb/essentia` is a fork of **[wo80/essentia](https://github.com/wo80/essentia)**, tracking its **`cmake`** branch.

It is *not* a fork of [MTG/essentia](https://github.com/MTG/essentia) in any practical sense. GitHub reports MTG as the network root, and that is misleading: MTG builds with waf and has **no CMake path at all**. The entire CMake build system this fork depends on — `CMakeLists.txt`, `cmake/modules/`, `packaging/build-dependencies-msvc.bat` — exists only on wo80's `cmake` branch.

**Upstream is `wo80/essentia`, branch `cmake`. Nothing is taken from `MTG/essentia@master` directly.** MTG's work reaches this fork only indirectly, when wo80 syncs his own `master` and merges forward.

## Why this document exists

On **2026-02-02** wo80 relaxed and then removed the Eigen3 version check in `2c9d9e6` and `a70cb36`.

On **2026-02-05** — three days later — the same problem was solved independently here, twice, in `9371de9` and `d77a465`. A third variant, `cad9172b`, existed only in a local working copy and was never pushed.

Three fixes for a problem upstream had already fixed. All three were dropped during the rebase in DES-39, because upstream's version was strictly better: it removed the version bound entirely, where the local attempts kept narrowing it (`3.3...5.99`, `3.3...6.0`).

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

The procedure, as used in DES-39:

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

As of 2026-09-01 the delta is 14 commits on top of `wo80/cmake@4d95fc4`. Regenerate with `git log --oneline wo80/cmake..cmake`.

**CI workflow** — `.github/workflows/build-cmake.yml` (8 commits). Fork-specific and staying that way. It builds a six-leg matrix (Linux/macOS/Windows × `USE_TENSORFLOW` ON/OFF) in Release, because `USE_TENSORFLOW=OFF` is what the FMDB desktop app ships and upstream does not exercise it. Upstream's CI serves upstream's needs.

**TensorFlow discovery** — `cmake/modules/FindTensorFlow.cmake` and TF search paths (`8f47e00`, and part of `3b46639`). Fork-specific for now; tied to how this project installs libtensorflow in CI. Revisit if upstream's discovery improves.

**YAML module casing** — `cmake/modules/FindYAML.cmake` (`8d4a189`, and part of `3b46639`). **Sent upstream as #10 below.** Two halves: the call site `find_package(Yaml)` → `YAML` in `CMakeLists.txt`, and the module's own `find_package_handle_standard_args(Yaml)` / `Yaml_FOUND` → `YAML`. Drop both on the rebase after #10 merges.

**Optional-dependency guards** — `src/algorithms/standard/CMakeLists.txt` (2 commits, DES-43). **Upstream candidates.** `resample` was compiled without libsamplerate, and the vDSP FFT sources were gated on `ESSENTIA_USE_ACCEL`, a variable set nowhere. Neither is FMDB-specific.

**Example placeholder** — `src/examples/streaming_tensorflowpredict.cpp` (1 commit). Trivial; upstream candidate.

### Already sent upstream

| PR | Change | Status |
| --- | --- | --- |
| [wo80/essentia#10](https://github.com/wo80/essentia/pull/10) | `find_package(Yaml)` → `YAML` at the call site, and the same inside `FindYAML.cmake`. The module file is `FindYAML.cmake`, so on a case-sensitive file system it was never loaded and YAML support was silently disabled | open |
| [wo80/essentia#11](https://github.com/wo80/essentia/pull/11) | Quote the value expansion in `essentia_check_set`; a list value clobbers a caller-scope variable, an empty value fails configure | open |

When one of these merges, drop the corresponding fork commit on the next rebase rather than carrying both.

## Known local-only workaround

`#undef PC` before `#include <Accelerate/Accelerate.h>` in `ffta.h`, `fftacomplex.h`, `iffta.h`, `ifftacomplex.h`.

`src/essentia/streaming/algorithms/poolstorage.h:164` defines `#define PC essentia::streaming::PoolConnector`. Accelerate reaches CarbonCore's `MachineExceptions.h`, whose `MachineInformationPowerPC` struct has a field named `PC`, and the macro rewrites Apple's field declaration.

This is containment, not a fix. The real fix — `poolstorage.h` not putting a two-letter macro in a public header — is a wider change and belongs upstream. Do not send the `#undef` upstream as-is.
