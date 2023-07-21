const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;

pub const Distance = enum {
    HammingDistance,
    LevenshteinDistance,
};

pub fn HammingDistance(comptime T: type) type {
    return struct {
        pub fn distance(a: *const T, b: *const T, allocator: ?Allocator) !isize {
            _ = allocator;

            switch (T) {
                []const u8 => {
                    var res: isize = 0;
                    var a_view = try unicode.Utf8View.init(a.*);
                    var b_view = try unicode.Utf8View.init(b.*);
                    var a_it = a_view.iterator();
                    var b_it = b_view.iterator();

                    while (a_it.nextCodepoint()) |ca| {
                        const cb = b_it.nextCodepoint();
                        if (cb == null) {
                            break;
                        }

                        if (ca != cb) {
                            res += 1;
                        }
                    }
                    return @intCast(res);
                },
                else => switch (@typeInfo(T)) {
                    .Int => {
                        var res: isize = 0;
                        var n = (a.* ^ b.*);
                        while (n != 0) {
                            n = n & (n - 1);
                            res += 1;
                        }
                        return res;
                    },
                    else => {
                        @compileError("Unsupported type " ++ @typeName(T) ++ "\n");
                    },
                },
            }
        }
    };
}

pub fn LevenshteinDistance(comptime T: type) type {
    return struct {
        pub fn distance(a: *const T, b: *const T, allocator: ?Allocator) !isize {
            if (std.mem.eql(u8, a.*, b.*)) {
                return 0;
            }

            const a_len = try unicode.utf8CountCodepoints(a.*);
            const b_len = try unicode.utf8CountCodepoints(b.*);

            if (a_len == 0) {
                return @intCast(b_len);
            }
            if (b_len == 0) {
                return @intCast(a_len);
            }

            var res: usize = 0;
            var cache = std.ArrayList(usize).init(allocator.?);
            defer cache.deinit();
            var a_dist: usize = undefined;
            var b_dist: usize = undefined;
            for (1..a_len + 1) |i| {
                try cache.append(i);
            }

            var b_view = try unicode.Utf8View.init(b.*);
            var b_it = b_view.iterator();
            var ib: usize = 0;
            while (b_it.nextCodepoint()) |cb| : (ib += 1) {
                res = ib;
                a_dist = ib;

                var ia: usize = 0;
                var a_view = try unicode.Utf8View.init(a.*);
                var a_it = a_view.iterator();
                while (a_it.nextCodepoint()) |ca| : (ia += 1) {
                    if (ca == cb) {
                        b_dist = a_dist;
                    } else {
                        b_dist = a_dist + 1;
                    }

                    a_dist = cache.items[ia];

                    if (a_dist > res) {
                        if (b_dist > res) {
                            res = res + 1;
                        } else {
                            res = b_dist;
                        }
                    } else if (b_dist > a_dist) {
                        res = a_dist + 1;
                    } else {
                        res = b_dist;
                    }
                    cache.items[ia] = res;
                }
            }
            return @intCast(res);
        }
    };
}
