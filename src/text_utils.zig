const std = @import("std");

pub fn renderTemplate(
    allocator: std.mem.Allocator,
    template: []const u8,
    values: std.StringHashMap([]const u8),
) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < template.len) {
        if (template[i] == '{') {
            if (std.mem.indexOfScalarPos(u8, template, i, '}')) |close| {
                const key = template[i + 1 .. close];
                if (values.get(key)) |val| {
                    try result.appendSlice(allocator, val);
                    i = close + 1;
                    continue;
                }
            }
        }
        try result.append(allocator, template[i]);
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

pub fn repeat(
    allocator: std.mem.Allocator,
    s: []const u8,
    n: usize,
) ![]u8 {
    const out = try allocator.alloc(u8, s.len * n);
    errdefer allocator.free(out);

    for (0..n) |i| {
        const start = i * s.len;
        @memcpy(out[start .. start + s.len], s);
    }

    return out;
}
