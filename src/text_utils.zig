const std = @import("std");

pub fn filenameToIdentifier(
    allocator: std.mem.Allocator,
    filename: []const u8,
) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    if (filename.len == 0) {
        return allocator.dupe(u8, "_");
    }

    if (std.ascii.isDigit(filename[0])) {
        try out.append(allocator, '_');
    }

    var last_was_underscore = false;

    for (filename) |c| {
        if (std.ascii.isAlphabetic(c) or std.ascii.isDigit(c) or c == '_') {
            try out.append(allocator, c);
            last_was_underscore = false;
        } else {
            if (!last_was_underscore) {
                try out.append(allocator, '_');
                last_was_underscore = true;
            }
        }
    }

    if (out.items.len == 0) {
        try out.append(allocator, '_');
    }

    return out.toOwnedSlice(allocator);
}

pub fn repeat(
    allocator: std.mem.Allocator,
    s: []const u8,
    n: usize,
) !?[]u8 {
    if (n == 0) return null;

    const out = try allocator.alloc(u8, s.len * n);
    errdefer allocator.free(out);

    for (0..n) |i| {
        const start = i * s.len;
        @memcpy(out[start .. start + s.len], s);
    }

    return out;
}
