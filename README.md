# BK-tree

[![CI](https://github.com/dying-will-bullet/bktree/actions/workflows/ci.yaml/badge.svg)](https://github.com/dying-will-bullet/bktree/actions/workflows/ci.yaml)
![](https://img.shields.io/badge/language-zig-%23ec915c)

Implementing a Brukhard Keller tree data structure that allows for querying of "close" matches on discrete distances.

## Feature

- `HammingDistance`: int type and unicode bytes.
- `LevenshteinDistance`: unicode bytes.

## Example

```zig
const std = @import("std");
const bktree = @import("bktree");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var tree = bktree.BkTree([]const u8, bktree.LevenshteinDistance([]const u8)).init(allocator);
    defer tree.deinit();

    // word list
    const words = &[_][]const u8{
        "isValid",
        "isInvalid",
        "valid",
        "invalid",
        "validated",
    };

    // insert to the BK-Tree
    try tree.insertSlice(words);

    // A list of words with two edit distances from "inInvald".
    var it = try tree.find("inInvald", 2);

    std.debug.print("Found misspell word '{s}'.\n", .{"inInvald"});
    // iterate results
    while (try it.next()) |match| {
        // match[0] is the pointer of value.
        // match[1] is the edit distances
        std.debug.print("Did you mean '{s}'?\n", .{match[0].*});
    }
}
```

## LICENSE

MIT
