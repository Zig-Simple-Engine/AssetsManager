const std = @import("std");
const mem = std.mem;
const text_utils = @import("text_utils.zig");
const assets_tree = @import("assets_tree.zig");

pub fn writeFile(init: std.process.Init, path: []const u8, text: []const u8) !void {
    const cwd = std.Io.Dir.cwd();

    if (std.fs.path.dirname(path)) |dir| {
        try cwd.createDirPath(init.io, dir);
    }

    const file = try cwd.createFile(init.io, path, .{});
    defer file.close(init.io);

    try file.writeStreamingAll(init.io, text);
}

pub fn toStructText(node: *assets_tree.Node, allocator: mem.Allocator, path: []const u8, depth: u32) ![]u8 {
    var str_list: std.ArrayList(u8) = .empty;
    errdefer str_list.deinit(allocator);

    var prefix: []u8 = "";
    if (depth != 0) {
        prefix = try text_utils.repeat(allocator, "    ", depth);
    }

    var map_it = node.map.iterator();
    while (map_it.next()) |entry| {
        try str_list.appendSlice(allocator, prefix);
        if (entry.value_ptr.isLeaf()) {
            try str_list.appendSlice(allocator, "pub const ");
            try str_list.appendSlice(allocator, entry.key_ptr.*);
            try str_list.appendSlice(allocator, " = @embedFile(\"");
            try str_list.appendSlice(allocator, path);
            try str_list.appendSlice(allocator, entry.key_ptr.*);
            try str_list.appendSlice(allocator, "\");\n");
        } else {
            try str_list.appendSlice(allocator, "pub const ");
            try str_list.appendSlice(allocator, entry.key_ptr.*);
            try str_list.appendSlice(allocator, " = struct {\n");

            var child_path_list: std.ArrayList(u8) = .empty;
            try child_path_list.appendSlice(allocator, path);
            try child_path_list.appendSlice(allocator, entry.key_ptr.*);
            try child_path_list.appendSlice(allocator, entry.value_ptr.*.separator);
            const subnode_string = try toStructText(entry.value_ptr, allocator, child_path_list.items, depth + 1);
            child_path_list.deinit(allocator);

            try str_list.appendSlice(allocator, subnode_string);

            allocator.free(subnode_string);
            try str_list.appendSlice(allocator, prefix);
            try str_list.appendSlice(allocator, "};\n");
        }
    }

    if (depth != 0) allocator.free(prefix);

    return str_list.toOwnedSlice(allocator);
}

pub fn buildAssetsDirToZigFile(init: std.process.Init, zig_file_path: []const u8, assets_dir: []const u8) !void {
    const gpa = init.gpa;
    var root = try assets_tree.create(init, assets_dir);
    defer root.deinitRecursively(gpa);

    var relative_path = assets_dir;
    var relative_path_formated = relative_path;
    var free_relative_path = false;
    if (std.fs.path.dirname(zig_file_path)) |dir| {
        relative_path = try std.fs.path.relativePosix(gpa, ".", dir, assets_dir);
        relative_path_formated = try std.fmt.allocPrint(gpa, "{s}/", .{relative_path});
        free_relative_path = true;
    }

    std.debug.print("Tree {s}: \n", .{assets_dir});
    const toStructText_result = try toStructText(&root, gpa, relative_path_formated, 0);
    try writeFile(init, zig_file_path, toStructText_result);
    defer gpa.free(toStructText_result);
    std.debug.print("{s}\n", .{toStructText_result});

    if (free_relative_path) {
        gpa.free(relative_path);
        gpa.free(relative_path_formated);
    }
}
