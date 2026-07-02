const std = @import("std");
const mem = std.mem;
const text_utils = @import("text_utils.zig");

fn printHashMap(map: std.StringHashMap(Node)) void {
    var map_it = map.iterator();
    var counter: usize = 0;
    while (map_it.next()) |entry| : (counter += 1) {
        std.debug.print("    [{}]k: {s}\n", .{ counter, entry.key_ptr.* });
    }
}

pub const Node = struct {
    map: std.StringHashMap(Node),
    separator: []const u8,

    pub var depth_prefix = "----";

    pub fn init(allocator: mem.Allocator, separator: []const u8) Node {
        return .{
            .map = .init(allocator),
            .separator = separator,
        };
    }

    pub fn deinitRecursively(self: *Node, allocator: std.mem.Allocator) void {
        var map_it = self.map.iterator();
        while (map_it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinitRecursively(allocator);
        }

        self.map.deinit();
    }

    pub fn isLeaf(self: Node) bool {
        return self.map.count() == 0;
    }

    pub fn toString(self: Node, allocator: mem.Allocator, depth: u32) ![]u8 {
        var str_list: std.ArrayList(u8) = .empty;
        errdefer str_list.deinit(allocator);

        var prefix: []u8 = "";
        if (depth != 0) {
            prefix = try text_utils.repeat(allocator, Node.depth_prefix, depth);
        }

        var map_it = self.map.iterator();
        while (map_it.next()) |entry| {
            if (depth != 0) try str_list.appendSlice(allocator, prefix);
            if (entry.value_ptr.isLeaf()) {
                try str_list.appendSlice(allocator, entry.key_ptr.*);
                try str_list.append(allocator, '\n');
            } else {
                try str_list.appendSlice(allocator, entry.key_ptr.*);
                try str_list.append(allocator, '\n');
                const subnode_string = try entry.value_ptr.toString(allocator, depth + 1);
                try str_list.appendSlice(allocator, subnode_string);
                allocator.free(subnode_string);
            }
        }

        if (depth != 0) allocator.free(prefix);

        return str_list.toOwnedSlice(allocator);
    }
};

pub fn create(init: std.process.Init, target_dir: []const u8) !Node {
    const io = init.io;
    const gpa = init.gpa;

    var dir = try std.Io.Dir.cwd().openDir(io, target_dir, .{
        .iterate = true,
    });
    defer dir.close(io);

    var walker = try dir.walk(gpa);
    defer walker.deinit();
    var root: Node = .init(gpa, "");

    while (try walker.next(io)) |dir_entry| {
        if (dir_entry.kind == .file) {
            // std.debug.print("{s}\n", .{dir_entry.path});
            var component_it = std.fs.path.componentIterator(dir_entry.path);
            var target = &root;

            while (component_it.next()) |component_entry| {
                var name_it = std.mem.splitScalar(u8, component_entry.name, '.');
                const seprator = if (component_it.peekNext() == null) "." else "/";
                while (name_it.next()) |name_entry| {
                    const sub_node = target.map.getPtr(name_entry);
                    if (sub_node) |node| {
                        target = node;
                    } else {
                        const name_copy = try gpa.dupe(u8, name_entry);
                        errdefer gpa.free(name_copy);
                        try target.map.put(name_copy, .init(gpa, seprator));
                        target = target.map.getPtr(name_entry).?;
                    }
                }
            }
        }
    }

    return root;
}
