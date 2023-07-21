const std = @import("std");
const Tuple = std.meta.Tuple;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const HammingDistance = @import("distance.zig").HammingDistance;
pub const LevenshteinDistance = @import("distance.zig").LevenshteinDistance;

pub fn Node(comptime T: type) type {
    return struct {
        word: T,
        children: std.ArrayList(Tuple(&[_]type{ isize, Node(T) })),

        const Self = @This();
        pub fn init(allocator: Allocator, word: T) Self {
            return Self{
                .word = word,
                .children = std.ArrayList(Tuple(&[_]type{ isize, Node(T) })).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.children.items) |*item| {
                item[1].deinit();
            }
            self.children.deinit();
        }
    };
}

pub fn BkTree(comptime T: type, comptime D: anytype) type {
    return struct {
        allocator: Allocator,
        root: ?Node(T),

        const dist_fn = D.distance;
        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = null,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.root != null) {
                self.root.?.deinit();
            }
        }

        pub fn insertSlice(self: *Self, words: []const T) !void {
            for (words) |word| {
                try self.insert(word);
            }
        }

        pub fn insert(self: *Self, val: T) !void {
            if (self.root == null) {
                self.root = Node(T).init(self.allocator, val);
            } else {
                // & here
                var root = &self.root.?;

                while (true) {
                    const k = try dist_fn(&root.word, &val, self.allocator);
                    if (k == 0) {
                        return;
                    }

                    var pos: ?usize = null;
                    for (root.children.items, 0..) |item, i| {
                        if (item[0] == k) {
                            pos = i;
                        }
                    }

                    if (pos == null) {
                        try root.children.append(.{
                            k, Node(T).init(self.allocator, val),
                        });
                    } else {
                        root = &root.children.items[pos.?][1];
                    }
                }
            }
        }

        pub fn find(self: Self, val: T, max_dist: isize) !std.ArrayList(Tuple(&[_]type{ *const T, isize })) {
            var res = std.ArrayList(Tuple(&[_]type{ *const T, isize })).init(self.allocator);

            if (self.root == null) {
                return res;
            }

            var candidates = std.ArrayList(*const Node(T)).init(self.allocator);
            defer candidates.deinit();
            try candidates.append(&self.root.?);

            while (candidates.items.len > 0) {
                const n = candidates.orderedRemove(0);
                const distance = try dist_fn(&n.word, &val, self.allocator);
                if (distance <= max_dist) {
                    try res.append(.{ &n.word, distance });
                }

                // * here
                for (n.children.items) |*item| {
                    if (try std.math.absInt((item[0] - distance)) <= max_dist) {
                        try candidates.append(&item[1]);
                    }
                }
            }
            return res;
        }
    };
}

// --------------------------------------------------------------------------------
//                                   Testing
// --------------------------------------------------------------------------------

fn expectEqual(comptime T: type, acutal: Tuple(&[_]type{ *const T, isize }), expect_val: T, expect_dist: isize) !void {
    try testing.expectEqual(expect_val, acutal[0].*);
    try testing.expectEqual(expect_dist, acutal[1]);
}

test "BkTree int hamming distance" {
    var tree = BkTree(i32, HammingDistance(i32)).init(testing.allocator);
    defer tree.deinit();

    try tree.insertSlice(&[_]i32{ 0, 4, 5, 14, 15 });
    const res = try tree.find(13, 1);
    defer res.deinit();

    try testing.expect(res.items.len == 2);
    try expectEqual(i32, res.items[0], 5, 1);
    try expectEqual(i32, res.items[1], 15, 1);
}

test "BkTree ascii string hamming distance" {
    var tree = BkTree([]const u8, HammingDistance([]const u8)).init(testing.allocator);
    defer tree.deinit();

    const words = &[_][]const u8{
        "kathlin",
        "karolin",
        "kathrin",
        "c4rorin",
        "carolin",
    };
    try tree.insertSlice(words);

    const res = try tree.find("kathlin", 4);
    defer res.deinit();
    try testing.expect(res.items.len == 4);
    try expectEqual([]const u8, res.items[0], "kathlin", 0);
    try expectEqual([]const u8, res.items[1], "karolin", 2);
    try expectEqual([]const u8, res.items[2], "kathrin", 1);
    try expectEqual([]const u8, res.items[3], "carolin", 3);
}

test "BkTree unicode string hamming distance" {
    var tree = BkTree([]const u8, HammingDistance([]const u8)).init(testing.allocator);
    defer tree.deinit();

    const words = &[_][]const u8{
        "青い花",
        "赤の花",
        "白い花",
    };
    try tree.insertSlice(words);

    const res = try tree.find("蒼い花", 1);
    defer res.deinit();
    try testing.expect(res.items.len == 2);
    try expectEqual([]const u8, res.items[0], "青い花", 1);
    try expectEqual([]const u8, res.items[1], "白い花", 1);
}

test "BkTree ascii string levenshtein distance" {
    var tree = BkTree([]const u8, LevenshteinDistance([]const u8)).init(testing.allocator);
    defer tree.deinit();

    const words = &[_][]const u8{ "book", "books", "boo", "boon", "cook", "cake", "cape", "cart" };
    try tree.insertSlice(words);

    const res = try tree.find("bo", 2);
    defer res.deinit();

    try testing.expect(res.items.len == 3);
    try expectEqual([]const u8, res.items[0], "book", 2);
    try expectEqual([]const u8, res.items[1], "boo", 1);
    try expectEqual([]const u8, res.items[2], "boon", 2);
}

test "BkTree unicode string levenshtein distance" {
    var tree = BkTree([]const u8, LevenshteinDistance([]const u8)).init(testing.allocator);
    defer tree.deinit();

    const words = &[_][]const u8{
        "青い花",
        "赤の花",
        "白い花",
        "蒼い",
    };
    try tree.insertSlice(words);

    const res = try tree.find("蒼い花", 1);
    defer res.deinit();
    try testing.expect(res.items.len == 3);
    try expectEqual([]const u8, res.items[0], "青い花", 1);
    try expectEqual([]const u8, res.items[1], "白い花", 1);
    try expectEqual([]const u8, res.items[2], "蒼い", 1);
}
