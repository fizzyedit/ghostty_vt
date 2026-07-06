const std = @import("std");

// Intentionally a no-op. Consumers reach into this package's `include/` and
// `lib/<target>/` via `dep.path(...)`, not `dep.artifact(...)`, so there is
// nothing to build here. This file only needs to exist so `zig build`
// recognizes the fetched tree as a package.
pub fn build(b: *std.Build) void {
    _ = b;
}
