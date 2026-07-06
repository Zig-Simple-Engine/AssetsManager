const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const assets_builder = @import("src/assets_builder.zig");
const assets_tree = @import("src/assets_tree.zig");
const descriptors = @import("src/descriptors.zig");

pub fn main(init: std.process.Init) !void {
    var file_descriptor: descriptors.ZigEmbedFileDescriptor = .{};
    var dir_descriptor: descriptors.ZigDirectoryDescriptor = .{};

    const descriptors_array = [_]*const descriptors.Descriptor{
        &file_descriptor.descriptor(),
        &dir_descriptor.descriptor(),
    };

    try assets_builder.createCodeFileFromAssets(init, "generated/src.zig", ".", .{
        .print_results = false,
        .descriptors = &descriptors_array,
    });
}
