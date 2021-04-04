const std = @import("std");
const Vector = std.meta.Vector;

pub const Float4 = Vector(4, f32);
pub const Float3 = [3]f32; // Vector(3, f32) is 16 byte aligned
pub const VFloat3 = Vector(3, f32);
pub const Float2 = Vector(2, f32);

pub const Float4x4 = extern struct {
    rows: [4]Float4 = .{
        Float4{ 1, 0, 0, 0 },
        Float4{ 0, 1, 0, 0 },
        Float4{ 0, 0, 1, 0 },
        Float4{ 0, 0, 0, 1 },
    },
};

pub const Float3x4 = extern struct {
    rows: [3]Float4 = .{
        Float4{ 1, 0, 0, 0 },
        Float4{ 0, 1, 0, 0 },
        Float4{ 0, 0, 1, 0 },
    },
};

pub const Float3x3 = extern struct {
    rows: [3]Float3 = .{
        Float3{ 1, 0, 0 },
        Float3{ 0, 1, 0 },
        Float3{ 0, 0, 1 },
    },
};

pub const Transform = extern struct {
    const Self = @This();

    position: Float3 = Float3{ 0, 0, 0 },
    scale: Float3 = Float3{ 1, 1, 1 },
    rotation: Float3 = Float3{ 0, 0, 0 },

    pub fn translate(self: *Self, p: VFloat3) void {
        self.position = @as(VFloat3, self.position) + p;
    }
    pub fn scaleBy(self: *Self, p: VFloat3) void {
        // Note: The original code does += here but that might be a bug.
        // This should maybe be *= instead.
        self.scale = @as(VFloat3, self.scale) + p;
    }
    pub fn rotate(self: *Self, p: VFloat3) void {
        self.rotation = @as(VFloat3, self.rotation) + p;
    }

    pub fn toMatrix(self: Self) Float4x4 {
        const p: Float4x4 = .{ .rows = .{
            .{1, 0, 0, self.position[0]},
            .{0, 1, 0, self.position[1]},
            .{0, 0, 1, self.position[2]},
            .{0, 0, 0, 1},
        }};

        const r = blk: {
            // whee vectors!
            const cos = @cos(@as(VFloat3, self.rotation));
            const sin = @sin(@as(VFloat3, self.rotation));

            var rx: Float4x4 = .{};
            rx.rows[1] = .{0, cos[0], -sin[0], 0};
            rx.rows[2] = .{0, sin[0],  cos[0], 0};

            var ry: Float4x4 = .{};
            ry.rows[0] = .{cos[1], 0, sin[1], 0};
            ry.rows[2] = .{-sin[1], 0, cos[1], 0};

            var rz: Float4x4 = .{};
            rz.rows[0] = .{cos[2], -sin[2], 0, 0};
            rz.rows[1] = .{sin[2], cos[2], 0, 0};

            const tmp = mulmf44(rx, ry);
            break :blk mulmf44(tmp, rz);
        };

        var s: Float4x4 = .{ .rows = .{
            .{self.scale[0], 0, 0, 0},
            .{0, self.scale[1], 0, 0},
            .{0, 0, self.scale[2], 0},
            .{0, 0, 0, 1},
        }};

        return mulmf44(s, mulmf44(p, r));
    }
};

pub fn f4tof3(f: Float4) VFloat3 {
    return .{ f[0], f[1], f[2] };
}
pub fn f3tof4(f: VFloat3, w: f32) Float4 {
    return .{ f[0], f[1], f[2], w };
}

pub fn dotf3(a: VFloat3, b: VFloat3) f32 {
    return @reduce(.Add, a * b);
}
pub fn dotf4(a: Float4, b: Float4) f32 {
    return @reduce(.Add, a * b);
}
pub fn crossf3(a: VFloat3, b: VFloat3) VFloat3 {
    const x1 = @shuffle(f32, a, undefined, [_]i32{1, 2, 0});
    const x2 = @shuffle(f32, a, undefined, [_]i32{2, 0, 1});
    const y1 = @shuffle(f32, b, undefined, [_]i32{2, 0, 1});
    const y2 = @shuffle(f32, b, undefined, [_]i32{1, 2, 0});
    return x1 * y1 - x2 * y2;
}

pub fn magf3(v: VFloat3) f32 {
    return std.math.sqrt(dotf3(v, v));
}
pub fn magsqf3(v: VFloat3) f32 {
    return dotf3(v, v);
}
pub fn normf3(v: VFloat3) VFloat3 {
    return v / @splat(3, magf3(v));
}

pub fn magf4(v: Float4) f32 {
    return std.math.sqrt(dotf4(v, v));
}
pub fn magsqf4(v: Float4) f32 {
    return dotf4(v, v);
}

pub fn mulf33(m: *Float3x3, v: VFloat3) void {
    m.rows[0] = @as(VFloat3, m.rows[0]) * v;
    m.rows[1] = @as(VFloat3, m.rows[1]) * v;
    m.rows[2] = @as(VFloat3, m.rows[2]) * v;
}
pub fn mulf34(m: *Float3x4, v: Float4) void {
    m.rows[0] *= v;
    m.rows[1] *= v;
    m.rows[2] *= v;
}
pub fn mulf44(m: *Float4x4, v: Float4) void {
    m.rows[0] *= v;
    m.rows[1] *= v;
    m.rows[2] *= v;
    m.rows[3] *= v;
}

pub fn mulmf34(x: Float3x4, y: Float3x4) Float3x4 {
    var result: Float3x4 = undefined;

    comptime var row = 0;
    inline while (row < 3) : (row += 1) {
        const a = @splat(4, x.rows[row][0]) * y.rows[0];
        const b = @splat(4, x.rows[row][1]) * y.rows[1];
        const c = @splat(4, x.rows[row][2]) * y.rows[2];
        const d = @splat(4, x.rows[row][3]) * Float4{0,0,0,1};
        result.rows[row] = (a + b) + (c + d);
    }

    return result;
}
pub fn mulmf44(x: Float4x4, y: Float4x4) Float4x4 {
    var result: Float4x4 = undefined;

    comptime var row = 0;
    inline while (row < 4) : (row += 1) {
        const a = @splat(4, x.rows[row][0]) * y.rows[0];
        const b = @splat(4, x.rows[row][1]) * y.rows[1];
        const c = @splat(4, x.rows[row][2]) * y.rows[2];
        const d = @splat(4, x.rows[row][3]) * y.rows[3];
        result.rows[row] = (a + b) + (c + d);
    }

    return result;
}

pub fn lookForward(pos: VFloat3, forward: VFloat3, up: VFloat3) Float4x4 {
    const norm_forward = normf3(forward);
    const norm_right = normf3(crossf3(up, norm_forward));
    const norm_up = crossf3(norm_forward, norm_right);

    return .{ .rows = .{
        f3tof4(norm_right, -dotf3(norm_right, pos)),
        f3tof4(norm_up, -dotf3(norm_up, pos)),
        f3tof4(norm_forward, -dotf3(norm_forward, pos)),
        .{0, 0, 0, 1},
    } };
}
pub fn lookAt(pos: VFloat3, target: VFloat3, up: VFloat3) Float4x4 {
    return lookForward(pos, pos - target, up);
}
pub fn perspective(fovy: f32, aspect: f32, zn: f32, zf: f32) Float4x4 {
    const focal_length = 1 / std.math.tan(fovy * 0.5);

    const m00 = focal_length / aspect;
    const m11 = -focal_length;
    const m22 = zn / (zf - zn);
    const m23 = zf * m22;

    return .{ .rows = .{ 
        .{m00, 0, 0, 0},
        .{0, m11, 0, 0},
        .{0, 0, m22, m23},
        .{0, 0, -1, 0},
    }};
}
