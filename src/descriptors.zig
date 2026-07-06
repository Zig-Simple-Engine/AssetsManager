const std = @import("std");
const mem = std.mem;

const Node = @import("assets_tree.zig").Node;
const text_utils = @import("text_utils.zig");

pub const Descriptor = struct {
    pub const Data = struct {
        id_in_parent: u32,
        depth: u32,
        node: *Node,
        content: ?[]const u8,
        path_to_root_node: []const u8,
    };
    pub const VTable = struct {
        get_code: *const fn (*anyopaque, init: std.process.Init, descripting_data: Data) anyerror![]u8,
        is_suitable_data: *const fn (*anyopaque, init: std.process.Init, descripting_data: Data) anyerror!bool,
    };
    ptr: *anyopaque,
    vtable: VTable,

    pub fn isSuitableData(self: *const Descriptor, init: std.process.Init, descripting_data: Data) anyerror!bool {
        return self.vtable.is_suitable_data(self.ptr, init, descripting_data);
    }

    pub fn getCode(self: *const Descriptor, init: std.process.Init, descripting_data: Data) anyerror![]u8 {
        return self.vtable.get_code(self.ptr, init, descripting_data);
    }
};

pub const ZigEmbedFileDescriptor = struct {
    spaces_per_depth: usize = 4,

    pub fn isSuitableData(ptr: *anyopaque, init: std.process.Init, descripting_data: Descriptor.Data) anyerror!bool {
        _ = ptr;
        _ = init;
        const node = descripting_data.node;
        return node.kind == .file;
    }

    pub fn getCode(ptr: *anyopaque, init: std.process.Init, descripting_data: Descriptor.Data) anyerror![]u8 {
        const self: *ZigEmbedFileDescriptor = @ptrCast(@alignCast(ptr));
        const node = descripting_data.node;
        const depth = descripting_data.depth;
        const gpa = init.gpa;
        const path = try node.createPath(gpa);
        defer gpa.free(path);

        const prefix = try text_utils.repeat(gpa, " ", depth * self.spaces_per_depth);
        defer if (prefix) |prefix_value| gpa.free(prefix_value);

        if (node.name) |name| {
            const var_name = try text_utils.filenameToIdentifier(gpa, name);
            defer gpa.free(var_name);
            return std.fmt.allocPrint(gpa, "{s}pub const {s} = @embedFile(\"{s}{s}\");\n", .{
                prefix orelse "",
                var_name,
                descripting_data.path_to_root_node,
                path,
            });
        } else {
            return error.AttemptToCreateZigCodeFromNodeWithoutName;
        }
    }

    pub fn descriptor(self: *ZigEmbedFileDescriptor) Descriptor {
        return .{
            .ptr = self,
            .vtable = .{
                .get_code = getCode,
                .is_suitable_data = isSuitableData,
            },
        };
    }
};

pub const ZigDirectoryDescriptor = struct {
    spaces_per_depth: usize = 4,

    pub fn isSuitableData(ptr: *anyopaque, init: std.process.Init, descripting_data: Descriptor.Data) anyerror!bool {
        _ = ptr;
        _ = init;
        const node = descripting_data.node;
        return node.kind == .directory;
    }

    pub fn getCode(ptr: *anyopaque, init: std.process.Init, descripting_data: Descriptor.Data) anyerror![]u8 {
        const self: *ZigDirectoryDescriptor = @ptrCast(@alignCast(ptr));
        const node = descripting_data.node;
        const depth = descripting_data.depth;
        const gpa = init.gpa;
        const content = descripting_data.content;

        const prefix = try text_utils.repeat(gpa, " ", depth * self.spaces_per_depth);
        defer if (prefix) |prefix_value| gpa.free(prefix_value);

        const new_line_after_content =
            if (content != null and content.?[content.?.len - 1] == '\n') "" else "\n";

        if (node.name) |name| {
            const var_name = try text_utils.filenameToIdentifier(gpa, name);
            defer gpa.free(var_name);
            return std.fmt.allocPrint(gpa, "{s}{s}pub const {s} = struct {{\n{s}{s}{s}}};\n", .{
                if (descripting_data.id_in_parent == 0) "" else "\n",
                prefix orelse "",
                var_name,
                descripting_data.content orelse "",
                new_line_after_content,
                prefix orelse "",
            });
        } else {
            return error.AttemptToCreateZigCodeFromNodeWithoutName;
        }
    }

    pub fn descriptor(self: *ZigDirectoryDescriptor) Descriptor {
        return .{
            .ptr = self,
            .vtable = .{
                .get_code = getCode,
                .is_suitable_data = isSuitableData,
            },
        };
    }
};
