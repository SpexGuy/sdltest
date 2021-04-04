usingnamespace @import("common.zig");

pub const cpu_mesh: CpuMesh = .{
    .index_size = @sizeOf(@TypeOf(indices)),
    .geom_size =
        @sizeOf(@TypeOf(positions)) +
        @sizeOf(@TypeOf(colors)) +
        @sizeOf(@TypeOf(normals)),
    .index_count = indices.len,
    .vertex_count = positions.len,
    .indices = &indices,
    .positions = &positions,
    .colors = &colors,
    .normals = &normals,
};

// -------------- Data only below this point ------------------

const indices = [_]u16{
    0,  1,  2,  2,  1,  3,  // Front
    4,  5,  6,  6,  5,  7,  // Back
    8,  9,  10, 10, 9,  11, // Right
    12, 13, 14, 14, 13, 15, // Left
    16, 17, 18, 18, 17, 19, // Top
    20, 21, 22, 22, 21, 23, // Bottom
};

const positions = [_]Float3{
    // front
    .{-1, -1, -1}, // point blue
    .{ 1, -1, -1}, // point magenta
    .{-1,  1, -1}, // point cyan
    .{ 1,  1, -1}, // point white
    // back
    .{ 1, -1,  1}, // point red
    .{-1, -1,  1}, // point black
    .{ 1,  1,  1}, // point yellow
    .{-1,  1,  1}, // point green
    // right
    .{ 1, -1, -1}, // point magenta
    .{ 1, -1,  1}, // point red
    .{ 1,  1, -1}, // point white
    .{ 1,  1,  1}, // point yellow
    // left
    .{-1, -1,  1}, // point black
    .{-1, -1, -1}, // point blue
    .{-1,  1,  1}, // point green
    .{-1,  1, -1}, // point cyan
    // top
    .{-1,  1, -1}, // point cyan
    .{ 1,  1, -1}, // point white
    .{-1,  1,  1}, // point green
    .{ 1,  1,  1}, // point yellow
    // bottom
    .{-1, -1,  1}, // point black
    .{ 1, -1,  1}, // point red
    .{-1, -1, -1}, // point blue
    .{ 1, -1, -1}  // point magenta
};

const colors = [_]Float3{
    // front
    .{0, 0, 1}, // blue
    .{1, 0, 1}, // magenta
    .{0, 1, 1}, // cyan
    .{1, 1, 1}, // white
    // back
    .{1, 0, 0}, // red
    .{0, 0, 0}, // black
    .{1, 1, 0}, // yellow
    .{0, 1, 0}, // green
    // right
    .{1, 0, 1}, // magenta
    .{1, 0, 0}, // red
    .{1, 1, 1}, // white
    .{1, 1, 0}, // yellow
    // left
    .{0, 0, 0}, // black
    .{0, 0, 1}, // blue
    .{0, 1, 0}, // green
    .{0, 1, 1}, // cyan
    // top
    .{0, 1, 1}, // cyan
    .{1, 1, 1}, // white
    .{0, 1, 0}, // green
    .{1, 1, 0}, // yellow
    // bottom
    .{0, 0, 0}, // black
    .{1, 0, 0}, // red
    .{0, 0, 1}, // blue
    .{1, 0, 1}  // magenta
};

const normals = [_]Float3{
    // front
    .{ 0,  0,  1}, // forward
    .{ 0,  0,  1}, // forward
    .{ 0,  0,  1}, // forward
    .{ 0,  0,  1}, // forward
    // back
    .{ 0,  0, -1}, // backbard
    .{ 0,  0, -1}, // backbard
    .{ 0,  0, -1}, // backbard
    .{ 0,  0, -1}, // backbard
    // right
    .{ 1,  0,  0}, // right
    .{ 1,  0,  0}, // right
    .{ 1,  0,  0}, // right
    .{ 1,  0,  0}, // right
    // left
    .{-1,  0,  0}, // left
    .{-1,  0,  0}, // left
    .{-1,  0,  0}, // left
    .{-1,  0,  0}, // left
    // top
    .{ 0,  1,  0}, // up
    .{ 0,  1,  0}, // up
    .{ 0,  1,  0}, // up
    .{ 0,  1,  0}, // up
    // bottom
    .{ 0, -1,  0}, // down
    .{ 0, -1,  0}, // down
    .{ 0, -1,  0}, // down
    .{ 0, -1,  0}  // down
};
