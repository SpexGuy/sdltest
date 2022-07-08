const cmn = @import("common.zig");
const sdl = @import("sdl");
const simd = @import("simd.zig");
const std = @import("std");

pub const Camera = struct {
    transform: simd.Transform,
    aspect: f32,
    fov: f32,
    near: f32,
    far: f32,

    pub fn viewProjection(self: Camera) simd.Float4x4 {
        const model_matrix = self.transform.toMatrix();
        const forward = simd.f4tof3(model_matrix.rows[2]);
        const view = simd.lookForward(self.transform.position, forward, .{0, 1, 0});
        const proj = simd.perspective(self.fov, self.aspect, self.near, self.far);
        return simd.mulmf44(proj, view);
    }
};

pub const EditorCameraState = packed struct {
    const Self = @This();

    moving_forward: bool = false,
    moving_backward: bool = false,
    moving_left: bool = false,
    moving_right: bool = false,
    moving_up: bool = false,
    moving_down: bool = false,
    __pad0: u26 = 0,

    pub fn set(self: *Self, flags: Self) void {
        self.* = @bitCast(Self, @bitCast(u32, self.*) | @bitCast(u32, flags));
    }
    pub fn unset(self: *Self, flags: Self) void {
        self.* = @bitCast(Self, @bitCast(u32, self.*) & ~@bitCast(u32, flags));
    }
    pub fn isMoving(self: Self) bool {
        return @bitCast(u32, self) != 0;
    }
};

pub const EditorCameraController = struct {
    const Self = @This();

    speed: f32,
    state: EditorCameraState = .{},
    total_mouse_dx: i32 = 0,
    total_mouse_dy: i32 = 0,

    pub fn newFrame(self: *Self) void {
        self.total_mouse_dx = 0;
        self.total_mouse_dy = 0;
    }

    pub fn handleEvent(editor: *Self, event: sdl.Event) void {
        switch (event.type) {
            .KEYDOWN, .KEYUP => {
                const keysym = event.key.keysym;

                var state_delta: EditorCameraState = .{};

                switch (keysym.scancode) {
                    .W => state_delta.moving_forward = true,
                    .A => state_delta.moving_left = true,
                    .S => state_delta.moving_backward = true,
                    .D => state_delta.moving_right = true,
                    else => {},
                }

                switch (event.type) {
                    .KEYDOWN => editor.state.set(state_delta),
                    .KEYUP => editor.state.unset(state_delta),
                    else => unreachable,
                }
            },
            .MOUSEMOTION => {
                const mouse_motion = &event.motion;
                const button_state = mouse_motion.state;

                if (button_state != 0) {
                    editor.total_mouse_dx += mouse_motion.xrel;
                    editor.total_mouse_dy += mouse_motion.yrel;
                }
            },

            else => {},
        }
    }

    pub fn updateCamera(editor: *const Self, delta_time_seconds: f32, cam: *Camera) void {
        if (editor.state.isMoving()) {
            const mat = cam.transform.toMatrix();
            const right = simd.f4tof3(mat.rows[0]);
            //const up = simd.f4tof3(mat.rows[1]);
            const forward = simd.f4tof3(mat.rows[2]);

            const delta_speed = @splat(3, editor.speed * delta_time_seconds);
            var velocity: simd.VFloat3 = .{0, 0, 0};

            if (editor.state.moving_forward) {
                velocity -= forward * delta_speed;
            }
            if (editor.state.moving_backward) {
                velocity += forward * delta_speed;
            }
            if (editor.state.moving_left) {
                velocity -= right * delta_speed;
            }
            if (editor.state.moving_right) {
                velocity += right * delta_speed;
            }

            cam.transform.translate(velocity);
        }

        const pixel_angle = 0.00095;
        cam.transform.rotation[1] -= @intToFloat(f32, editor.total_mouse_dx) * pixel_angle;
        cam.transform.rotation[0] += @intToFloat(f32, editor.total_mouse_dy) * pixel_angle;

        const limit = std.math.pi / 2.0 * 0.99;
        cam.transform.rotation[0] = std.math.clamp(cam.transform.rotation[0], -limit, limit);
    }
};

