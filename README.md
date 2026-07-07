# ghostty_vt

Prebuilt **libghostty-vt** (the VT parser / terminal state machine cut from
[ghostty-org/ghostty](https://github.com/ghostty-org/ghostty)), built by this repo's CI and
published as GitHub Release assets — so downstream consumers (e.g.
[fizzyedit/ghostty](https://github.com/fizzyedit/ghostty)) can depend on it as a normal Zig
package instead of checking in a ~17MB static archive.

## Why this repo exists

ghostty's own `build.zig` requires **Zig 0.15.x**. Projects that consume libghostty-vt (like the
fizzy plugin toolchain) are on **Zig 0.16**, under which ghostty's build does not compile (`std.Build`
API drift) — so it can't be built in-tree as a normal dependency. This repo solves that by being
the one place that still runs Zig 0.15.x: its CI checks out a pinned ghostty commit, builds
libghostty-vt with 0.15.x for every target platform, and republishes the result as a release
so nothing needs Zig 0.15 (or the giant binary) downstream.

This repo's own `vX.Y.Z` tags are an independent version for the *package*, unrelated to
ghostty's own version numbers — see "Why a pinned commit, not a tag" below.

## What CI builds

On every `vX.Y.Z` tag push, [`.github/workflows/release.yml`](.github/workflows/release.yml):

1. Checks out `ghostty-org/ghostty` at the pinned ref (see `GHOSTTY_REF_DEFAULT` in the
   workflow).
2. Builds `libghostty-vt` with Zig 0.15.2 (`zig build -Demit-lib-vt -Doptimize=ReleaseFast`) for:
   - **macos-universal** — arm64+x86_64 fat binary via ghostty's own xcframework step (needs a
     real macOS runner + Xcode for `lipo`/`xcodebuild`).
   - **linux-x86_64**, **linux-aarch64** — cross-compiled from `ubuntu-latest`.
   - **windows-x86_64** — built on `windows-latest`.
3. Assembles one combined package: shared `include/ghostty/...` headers (identical across
   targets — pure C API, nothing platform-generated) + one static lib per target under
   `lib/<target>/` + a `GHOSTTY_COMMIT` file recording the exact ghostty commit built, plus the
   trivial `build.zig` / `build.zig.zon` from [`package/`](package/) so the tree fetches as a
   normal Zig package.
4. Publishes `ghostty-vt-vX.Y.Z.tar.gz` as a release asset on the tag.

## Why a pinned commit, not a tag

The static-lib / VT-only-xcframework build support we depend on (`-Demit-lib-vt`, see
`src/build/Config.zig` upstream) has **not shipped in any tagged ghostty release** — confirmed
absent as of `v1.3.1`, ghostty's latest tag at time of writing. It only exists on ghostty's `main`
branch. So `GHOSTTY_REF_DEFAULT` in the workflow pins an exact commit SHA on `main`, not a
release tag. When bumping it, re-verify `-Demit-lib-vt` still exists at the new SHA (grep
`src/build/Config.zig` for `emit_lib_vt`) before repinning — and re-check whether it has since
shipped in a tagged release, which would let this go back to tracking tags.

## Consuming from a Zig project

In the consumer's `build.zig.zon`:

```zig
.dependencies = .{
    .ghostty_vt = .{
        .url = "https://github.com/fizzyedit/ghostty_vt/releases/download/v0.1.0/ghostty-vt-v0.1.0.tar.gz",
        .hash = "...", // from `zig fetch --save <url>`
    },
},
```

In `build.zig`, pick the lib subpath for the current target and link it:

```zig
const ghostty_vt = b.dependency("ghostty_vt", .{});
const vt_lib = switch (target.result.os.tag) {
    .macos => "lib/macos-universal/libghostty-vt.a",
    .windows => "lib/x86_64-windows/ghostty-vt-static.lib",
    .linux => switch (target.result.cpu.arch) {
        .aarch64 => "lib/linux-aarch64/libghostty-vt.a",
        else => "lib/linux-x86_64/libghostty-vt.a",
    },
    else => @panic("unsupported target for ghostty_vt"),
};
lib.root_module.addIncludePath(ghostty_vt.path("include"));
lib.root_module.addObjectFile(ghostty_vt.path(vt_lib));
lib.root_module.link_libc = true;
```

## Bumping the pinned ghostty version

1. Update `GHOSTTY_REF_DEFAULT` in `.github/workflows/release.yml` to the new ghostty commit SHA
   (or tag, once `-Demit-lib-vt` ships in a release).
2. Bump this repo's own version and push a tag (e.g. `v0.2.0`) — independent of ghostty's version.
3. Once the release finishes, run `zig fetch --save https://github.com/fizzyedit/ghostty_vt/releases/download/<tag>/ghostty-vt-<tag>.tar.gz`
   in the consuming repo to update its `build.zig.zon` url+hash.

The C API is explicitly work-in-progress/unstable upstream — expect to review binding code
(e.g. `src/c.zig` in the plugin) whenever you bump this pin.
