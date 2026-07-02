const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("assets_manager", .{
        .root_source_file = b.path("root.zig"),
    });
}
