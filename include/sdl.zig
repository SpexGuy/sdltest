//! Note: This binding is incomplete.  So far it contains rwops, audio, and vulkan,
//! plus a few other utilities needed for this project.
//! This zig port binds the SDL library, which bears the following license:
//!
//!  Simple DirectMedia Layer
//!  Copyright (C) 1997-2020 Sam Lantinga <slouken@libsdl.org>
//!
//!  This software is provided 'as-is', without any express or implied
//!  warranty.  In no event will the authors be held liable for any damages
//!  arising from the use of this software.
//!
//!  Permission is granted to anyone to use this software for any purpose,
//!  including commercial applications, and to alter it and redistribute it
//!  freely, subject to the following restrictions:
//!
//!  1. The origin of this software must not be misrepresented; you must not
//!     claim that you wrote the original software. If you use this software
//!     in a product, an acknowledgment in the product documentation would be
//!     appreciated but is not required.
//!  2. Altered source versions must be plainly marked as such, and must not be
//!     misrepresented as being the original software.
//!  3. This notice may not be removed or altered from any source distribution.
//!
//! This file is not part of the original SDL source.

const std = @import("std");
const vk = @import("vk");

const sdl = @This();

const assert = std.debug.assert;
const endian = std.builtin.endian;

pub const CC = std.builtin.CallingConvention.C;

pub const IntBool = c_int;

pub const Point = struct { x: i32, y: i32 };
pub const FPoint = struct { x: f32, y: f32 };
pub const Rect = struct { x: i32, y: i32, w: i32, h: i32 };
pub const FRect = struct { x: f32, y: f32, w: f32, h: f32 };

pub const RWops = extern struct {
    pub const Whence = enum(c_int) {
        seek_set = 0,
        seek_cur = 1,
        seek_end = 2,
        _,
    };

    sizeFn: ?fn(context: *RWops) callconv(CC) i64,
    seekFn: ?fn(context: *RWops, offset: i64, whence: Whence) callconv(CC) i64,
    readFn: ?fn(context: *RWops, ptr: *anyopaque, size: usize, maxnum: usize) callconv(CC) usize,
    writeFn: ?fn(context: *RWops, ptr: *anyopaque, size: usize, num: usize) callconv(CC) usize,
    closeFn: ?fn(context: *RWops) callconv(CC) i32,

    type: enum(u32) {
        unknown,
        winfile,
        stdfile,
        jnifile,
        memory,
        memory_readonly,
        _,
    },

    hidden: extern union {
        androidio: extern struct {
            asset: ?*anyopaque,
        },
        windowsio: (
            if (std.builtin.os.tag == .windows)
                extern struct {
                    append: IntBool,
                    h: ?*anyopaque,
                    buffer: extern struct {
                        data: ?*anyopaque,
                        size: usize,
                        left: usize,
                    },
                }
            else
                extern struct {}
        ),
        stdio: extern struct {
            autoclose: IntBool,
            fp: ?*anyopaque, // FILE*
        },
        mem: extern struct {
            base: [*]u8,
            here: [*]u8,
            stop: [*]u8,
        },
        unknown: extern struct {
            data1: ?*anyopaque,
            data2: ?*anyopaque,
        },
    },
};

pub const audio = struct {
    pub const Format = packed struct {
        bit_size: u8,

        is_float: bool,
        __pad0: u3 = 0,
        is_big_endian: bool,
        __pad1: u2 = 0,
        is_signed: bool,

        pub const U8: audio.Format align(2) = .{ .bit_size = 8, .is_float = false, .is_big_endian = false, .is_signed = false };
        pub const S8: audio.Format align(2) = .{ .bit_size = 8, .is_float = false, .is_big_endian = false, .is_signed = true };
        pub const U16LSB: audio.Format align(2) = .{ .bit_size = 16, .is_float = false, .is_big_endian = false, .is_signed = false };
        pub const S16LSB: audio.Format align(2) = .{ .bit_size = 16, .is_float = false, .is_big_endian = false, .is_signed = true };
        pub const U16MSB: audio.Format align(2) = .{ .bit_size = 16, .is_float = false, .is_big_endian = true, .is_signed = false };
        pub const S16MSB: audio.Format align(2) = .{ .bit_size = 16, .is_float = false, .is_big_endian = true, .is_signed = true };
        pub const U16 = U16LSB;
        pub const S16 = S16LSB;

        pub const S32LSB: audio.Format align(2) = .{ .bit_size = 32, .is_float = false, .is_big_endian = false, .is_signed = true };
        pub const S32MSB: audio.Format align(2) = .{ .bit_size = 32, .is_float = false, .is_big_endian = true, .is_signed = true };
        pub const S32 = S32LSB;

        pub const F32LSB: audio.Format align(2) = .{ .bit_size = 32, .is_float = true, .is_big_endian = false, .is_signed = true };
        pub const F32MSB: audio.Format align(2) = .{ .bit_size = 32, .is_float = true, .is_big_endian = true, .is_signed = true };
        pub const F32 = F32LSB;

        pub const U16SYS = if (endian == .Little) U16LSB else U16MSB;
        pub const S16SYS = if (endian == .Little) S16LSB else S16MSB;
        pub const S32SYS = if (endian == .Little) S32LSB else S32MSB;
        pub const F32SYS = if (endian == .Little) F32LSB else F32MSB;

        pub const Int = u16;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
    };

    pub const AllowChangeFlags = packed struct {
        frequency: bool = false,
        format: bool = false,
        channels: bool = false,
        samples: bool = false,
        __pad0: u28 = 9,
    };

    pub const Callback = fn(user_data: ?*anyopaque, stream: [*]u8, len: c_int) callconv(CC) void;

    pub const Spec = extern struct {
        freq: i32,
        format: audio.Format align(2),
        channels: u8,
        silence: u8 = 0,
        samples: u16,
        padding: u16 = 0,
        size: u32 = 0,
        callback: ?Callback = null,
        user_data: ?*anyopaque = null,
    };

    pub const Filter = fn(cvt: ?*CVT, format: u16) callconv(CC) void;
    pub const CVT_MAX_FILTERS = 9;

    pub const CVT = extern struct {
        needed: i32,
        src_format: audio.Format align(2),
        dst_format: audio.Format align(2),
        rate_incr: f64 align(4),
        buf: ?[*]u8 align(4),
        len: i32,
        len_cvt: i32,
        len_mult: i32,
        len_ratio: f64 align(4),
        filters: [CVT_MAX_FILTERS + 1]?Filter align(4),
        filter_index: i32,
    };

    pub const DeviceID = enum(u32) {
        invalid = 0,
        default = 1,
        _,
    };

    pub const Status = enum (i32) {
        stopped,
        playing,
        paused,
        _,
    };

    pub const Stream = opaque{};

    pub const MIX_MAXVOLUME = 128;
};

pub const Format = enum (u32) {
    unknown = 0,

    index_1_lsb = initInt(.index_1, .@"4321", .none, 1, 0),
    index_1_msb = initInt(.index_1, .@"1234", .none, 1, 0),
    index_4_lsb = initInt(.index_4, .@"4321", .none, 4, 0),
    index_4_msb = initInt(.index_4, .@"1234", .none, 4, 0),
    index_8 = initInt(.index_8, .none, .none, 8, 1),

    rgb332 = initInt(.packed_8, .xrgb, .@"332", 8, 1),

    xrgb4444 = xrgb4444_value,
    xbgr4444 = xbgr4444_value,
    xrgb1555 = xrgb1555_value,
    xbgr1555 = xbgr1555_value,

    rgb444 = xrgb4444_value,
    bgr444 = xbgr4444_value,
    rgb555 = xrgb1555_value,
    bgr555 = xbgr1555_value,

    argb4444 = initInt(.packed_16, .argb, .@"4444", 16, 2),
    rgba4444 = initInt(.packed_16, .rgba, .@"4444", 16, 2),
    abgr4444 = initInt(.packed_16, .abgr, .@"4444", 16, 2),
    bgra4444 = initInt(.packed_16, .bgra, .@"4444", 16, 2),

    argb1555 = initInt(.packed_16, .argb, .@"1555", 16, 2),
    rgba5551 = initInt(.packed_16, .rgba, .@"5551", 16, 2),
    abgr1555 = initInt(.packed_16, .abgr, .@"1555", 16, 2),
    bgra5551 = initInt(.packed_16, .bgra, .@"5551", 16, 2),

    rgb565 = initInt(.packed_16, .xrgb, .@"565", 16, 2),
    bgr565 = initInt(.packed_16, .xbgr, .@"565", 16, 2),

    rgb24 = initInt(.array_u8, .rgb, .none, 24, 3),
    bgr24 = initInt(.array_u8, .bgr, .none, 24, 3),

    xrgb8888 = xrgb8888_value,
    rgbx8888 = rgbx8888_value,
    xbgr8888 = xbgr8888_value,
    bgrx8888 = bgrx8888_value,

    rgb888 = xrgb8888_value,
    bgr888 = xbgr8888_value,

    argb8888 = argb8888_value,
    rgba8888 = rgba8888_value,
    abgr8888 = abgr8888_value,
    bgra8888 = bgra8888_value,

    rgba32 = if (endian == .Little) abgr8888_value else rgba8888_value,
    argb32 = if (endian == .Little) bgra8888_value else argb8888_value,
    bgra32 = if (endian == .Little) argb8888_value else bgra8888_value,
    abgr32 = if (endian == .Little) rgba8888_value else abgr8888_value,

    argb2101010 = initInt(.packed_32, .argb, .@"2101010", 32, 4),

    YV12 = fourccInt("YV12"),
    IYUV = fourccInt("IYUV"),
    YUY2 = fourccInt("YUY2"),
    UYVY = fourccInt("UYVY"),
    YVYU = fourccInt("YVYU"),
    NV12 = fourccInt("NV12"),
    NV21 = fourccInt("NV21"),
    external_oes = fourccInt("OES "),

    _,

    const argb8888_value = initInt(.packed_32, .argb, .@"8888", 32, 4);
    const rgba8888_value = initInt(.packed_32, .rgba, .@"8888", 32, 4);
    const abgr8888_value = initInt(.packed_32, .abgr, .@"8888", 32, 4);
    const bgra8888_value = initInt(.packed_32, .bgra, .@"8888", 32, 4);
    const xrgb8888_value = initInt(.packed_32, .xrgb, .@"8888", 24, 4);
    const rgbx8888_value = initInt(.packed_32, .rgbx, .@"8888", 24, 4);
    const xbgr8888_value = initInt(.packed_32, .xbgr, .@"8888", 24, 4);
    const bgrx8888_value = initInt(.packed_32, .bgrx, .@"8888", 24, 4);
    const xrgb4444_value = initInt(.packed_16, .xrgb, .@"4444", 12, 2);
    const xbgr4444_value = initInt(.packed_16, .xbgr, .@"4444", 12, 2);
    const xrgb1555_value = initInt(.packed_16, .xrgb, .@"1555", 15, 2);
    const xbgr1555_value = initInt(.packed_16, .xbgr, .@"1555", 15, 2);

    pub fn isFourCC(self: Format) bool {
        return (self.toInt() != 0 and self.toFlags().is_raw != 1);
    }

    pub fn bitsPerPixel(self: Format) u8 {
        return self.toFlags().bits;
    }

    pub fn bytesPerPixel(self: Format) u8 {
        if (self.isFourCC()) {
            return if (
                self == .YUY2 or
                self == .UYVY or
                self == .YVYU
            ) 2 else 1;
        } else {
            return self.toFlags().bytes;
        }
    }

    pub fn isIndexed(self: Format) bool {
        return !self.isFourCC() and self.toFlags().type.isIndexedType();
    }
    pub fn isPacked(self: Format) bool {
        return !self.isFourCC() and self.toFlags().type.isPackedType();
    }
    pub fn isArray(self: Format) bool {
        return !self.isFourCC() and self.toFlags().type.isArrayType();
    }

    pub fn isAlpha(self: Format) bool {
        if (self.isPacked()) {
            const fmt = @intToEnum(PackedOrder, self.toFlags().order);
            return fmt == .argb
                or fmt == .rgba
                or fmt == .abgr
                or fmt == .bgra;
        } else if (self.isArray()) {
            const fmt = @intToEnum(ArrayOrder, self.toFlags().order);
            return fmt == .argb
                or fmt == .rgba
                or fmt == .abgr
                or fmt == .bgra;
        }
        return false;
    }

    const Flags = packed struct {
        bytes: u8,

        bits: u8,

        layout: PackedLayout,
        order: u4, // BitmapOrder, PackedOrder, or ArrayOrder, depending on _type.

        type: Type,
        is_raw: u4 = 1,

        pub fn toEnum(fmt: @This()) Format {
            return @bitCast(Format, fmt);
        }
    };
    fn toFlags(fmt: @This()) Flags {
        return @bitCast(Flags, fmt);
    }

    pub const Type = enum (u4) {
        unknown,
        index_1,
        index_4,
        index_8,
        packed_8,
        packed_16,
        packed_32,
        array_u8,
        array_u16,
        array_u32,
        array_f16,
        array_f32,
        _,

        pub fn isIndexedType(self: Type) bool {
            return self == .index_1
                or self == .index_4
                or self == .index_8;
        }
        pub fn isPackedType(self: Type) bool {
            return self == .packed_8
                or self == .packed_16
                or self == .packed_32;
        }
        pub fn isArrayType(self: Type) bool {
            return self == .array_u8
                or self == .array_u16
                or self == .array_u32
                or self == .array_f16
                or self == .array_f32;
        }
    };

    pub const BitmapOrder = enum (u4) {
        none,
        @"4321",
        @"1234",
        _,
    };
    pub const PackedOrder = enum (u4) {
        none,
        xrgb,
        rgbx,
        argb,
        rgba,
        xbgr,
        bgrx,
        abgr,
        bgra,
        _,
    };
    pub const ArrayOrder = enum (u4) {
        none,
        rgb,
        rgba,
        argb,
        bgr,
        bgra,
        abgr,
        _,
    };

    pub fn OrderOf(comptime _type: Type) type {
        if (_type.isBitmapType()) return BitmapOrder;
        if (_type.isPackedType()) return PackedOrder;
        if (_type.isArrayType()) return ArrayOrder;
        @compileError("No known order type for format type "++@tagName(_type));
    }

    pub const PackedLayout = enum (u4) {
        none,
        @"332",
        @"4444",
        @"1555",
        @"5551",
        @"565",
        @"8888",
        @"2101010",
        @"1010102",
        _,
    };

    pub fn fourcc(str: *const [4]u8) Format {
        return @intToEnum(Format, fourccInt(str));
    }
    fn fourccInt(str: *const [4]u8) u32 {
        return std.mem.readIntLittle(u32, str);
    }

    pub fn init(
        comptime _type: Type,
        order: OrderOf(_type),
        layout: PackedLayout,
        bits: u8,
        bytes: u8,
    ) Format {
        return @intToEnum(Format, initInt(_type, order, layout, bits, bytes));
    }
    fn initInt(
        comptime _type: Type,
        order: OrderOf(_type),
        layout: PackedLayout,
        bits: u8,
        bytes: u8,
    ) u32 {
        return @bitCast(u32, Flags{
            .bytes = bytes,
            .bits = bits,
            .layout = layout,
            .order = @enumToInt(order),
            .type = _type,
        });
    }
};

pub const BlendMode = enum (u32) {
    none = 0,
    blend = 1,
    add = 2,
    mod = 4,
    mul = 8,
    invalid = 0x7FFF_FFFF,
    _,
};

pub const BlendOperation = enum (u32) {
    add = 1,
    subtract = 2,
    rev_subtract = 3,
    minimum = 4,
    maximum = 5,
    _,
};

pub const BlendFactor = enum (u32) {
    zero = 1,
    one = 2,
    src_color = 3,
    one_minus_src_color = 4,
    src_alpha = 5,
    one_minus_src_alpha = 6,
    dst_color = 7,
    one_minus_dst_color = 8,
    dst_alpha = 9,
    one_minus_dst_alpha = 10,
    _,
};


pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
pub const Colour = Color;

pub const Palette = extern struct {
    ncolors: i32,
    colors: ?[*]Color,
    version: u32,
    refcount: i32,
};

pub const PixelFormat = extern struct {
    format: Format,
    palette: ?*Palette,
    bitsPerPixel: u8,
    bytesPerPixel: u8,
    padding: u16 = 0,
    rMask: u32,
    gMask: u32,
    bMask: u32,
    aMask: u32,
    rLoss: u8,
    gLoss: u8,
    bLoss: u8,
    aLoss: u8,
    rShift: u8,
    gShift: u8,
    bShift: u8,
    aShift: u8,
    refcount: i32,
    next: ?*const @This(),
};

pub const Window = opaque{
    pub const Flags = packed struct {
        fullscreen: bool = false,
        opengl: bool = false,
        shown: bool = false,
        hidden: bool = false,
        borderless: bool = false,
        resizable: bool = false,
        minimized: bool = false,
        maximized: bool = false,
        
        input_grabbed: bool = false,
        input_focus: bool = false,
        mouse_focus: bool = false,
        foreign: bool = false,
        desktop: bool = false, // use with fullscreen for fullscreen desktop
        allow_highdpi: bool = false,
        mouse_capture: bool = false,
        always_on_top: bool = false,

        skip_taskbar: bool = false,
        utility: bool = false,
        tooltip: bool = false,
        popup_menu: bool = false,
        __pad0: u4 = 0,

        __pad1: u4 = 0,
        vulkan: bool = false,
        metal: bool = false,
        __pad2: u2 = 0,

        pub const Int = u32;
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
        pub fn toInt(flags: @This()) Int {
            return @bitCast(Int, flags);
        }
    };

    pub const pos_undefined = posUndefinedDisplay(0);
    pub const pos_undefined_mask = 0x1fff_0000;
    pub fn posUndefinedDisplay(x: i32) i32 {
        return pos_undefined_mask | x;
    }
    pub fn posIsUndefined(p: i32) bool {
        return @bitCast(u32, p) & 0xFFFF_0000 == pos_undefined_mask;
    }

    pub const pos_centered = posCenteredDisplay(0);
    pub const pos_centered_mask = 0x2FFF_0000;
    pub fn posCenteredDisplay(x: i32) i32 {
        return pos_centered_mask | x;
    }
    pub fn posIsCentered(p: i32) bool {
        return @bitCast(u32, p) & 0xFFFF_0000 == pos_centered_mask;
    }

    pub const HitTestResult = enum(u32) {
        normal,
        draggable,
        resize_topleft,
        resize_top,
        resize_topright,
        resize_right,
        resize_bottomright,
        resize_bottom,
        resize_bottomleft,
        resize_left,
        _,
    };

    pub const HitTest = fn(
        win: *Window,
        area: ?*const Point,
        data: ?*anyopaque
    ) callconv(CC) HitTestResult;

    pub const ERR_NONSHAPEABLE_WINDOW = -1;
    pub const ERR_INVALID_SHAPE_ARGUMENT = -2;
    pub const ERR_WINDOW_LACKS_SHAPE = -3;

    pub const ShapeMode = extern struct {
        type: Type,
        parameters: Params,

        pub const Type = enum(u32) {
            default,
            binarize_alpha,
            reverse_binarize_alpha,
            color_key,
            _,
        };

        pub const Params = extern union {
            none: void,
            binarization_cutoff: u8,
            color_key: Color,
        };
    };

    pub fn create(title: ?[*:0]const u8, x: i32, y: i32, w: i32, h: i32, flags: Flags) callconv(.Inline) !*Window {
        return raw.SDL_CreateWindow(title, x, y, w, h, flags.toInt()) orelse error.SDL_ERROR;
    }
    pub fn createFrom(data: ?*anyopaque) callconv(.Inline) !*Window {
        return raw.SDL_CreateWindowFrom(data) orelse error.SDL_ERROR;
    }
    pub const getFromID = raw.SDL_GetWindowFromID;
    pub const getGrabbed = raw.SDL_GetGrabbedWindow;
    pub const destroy = raw.SDL_DestroyWindow;

    pub fn getDisplayIndex(window: *Window) callconv(.Inline) !u32 {
        const index = raw.SDL_GetWindowDisplayIndex(window);
        if (index < 0) return error.SDL_ERROR;
        return @intCast(u32, index);
    }
    pub fn setDisplayMode(window: *Window, mode: video.DisplayMode) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowDisplayMode(window, &mode);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn getDisplayMode(window: *Window) callconv(.Inline) !video.DisplayMode {
        var mode: video.DisplayMode = undefined;
        const rc = raw.SDL_GetWindowDisplayMode(window, &mode);
        if (rc < 0) return error.SDL_ERROR;
        return mode;
    }
    pub fn getPixelFormat(window: *Window) callconv(.Inline) !Format {
        const int = raw.SDL_GetWindowPixelFormat(window);
        if (int == 0) return error.SDL_ERROR;
        return @intToEnum(Format, int);
    }
    pub const getID = raw.SDL_GetWindowID;
    pub fn getFlags(window: *Window) callconv(.Inline) Flags {
        return Flags.fromInt(raw.SDL_GetWindowFlags(window));
    }
    pub const setTitle = raw.SDL_SetWindowTitle;
    pub const getTitle = raw.SDL_GetWindowTitle;
    pub const setIcon = raw.SDL_SetWindowIcon;
    pub const setData = raw.SDL_SetWindowData;
    pub const getData = raw.SDL_GetWindowData;
    pub const setPosition = raw.SDL_SetWindowPosition;
    pub fn getPosition(window: *Window) callconv(.Inline) Point {
        var p: Point = undefined;
        raw.SDL_GetWindowPosition(window, &p.x, &p.y);
        return p;
    }
    pub const setSize = raw.SDL_SetWindowSize;
    pub fn getSize(window: *Window) callconv(.Inline) Point {
        var p: Point = undefined;
        raw.SDL_GetWindowSize(window, &p.x, &p.y);
        return p;
    }

    pub const Borders = struct { top: i32, left: i32, bottom: i32, right: i32 };
    pub fn getBordersSize(window: *Window) callconv(.Inline) !Borders {
        var b: Borders = undefined;
        const rc = raw.SDL_GetWindowBordersSize(window, &b.top, &b.left, &b.bottom, &b.right);
        if (rc < 0) return error.SDL_ERROR;
        return b;
    }
    pub const setMinimumSize = raw.SDL_SetWindowMinimumSize;
    pub fn getMinimumSize(window: *Window) callconv(.Inline) Point {
        var p: Point = undefined;
        raw.SDL_GetWindowMinimumSize(window, &p.x, &p.y);
        return p;
    }
    pub const setMaximumSize = raw.SDL_SetWindowMaximumSize;
    pub fn getMaximumSize(window: *Window) callconv(.Inline) Point {
        var p: Point = undefined;
        raw.SDL_GetWindowMaximumSize(window, &p.x, &p.y);
        return p;
    }
    pub fn setBordered(window: *Window, bordered: bool) callconv(.Inline) void {
        raw.SDL_SetWindowBordered(window, @boolToInt(bordered));
    }
    pub fn setResizable(window: *Window, resizable: bool) callconv(.Inline) void {
        raw.SDL_SetWindowResizable(window, @boolToInt(resizable));
    }
    pub const show = raw.SDL_ShowWindow;
    pub const hide = raw.SDL_HideWindow;
    pub const raise = raw.SDL_RaiseWindow;
    pub const maximize = raw.SDL_MaximizeWindow;
    pub const minimize = raw.SDL_MinimizeWindow;
    pub const restore = raw.SDL_RestoreWindow;
    pub fn setFullscreen(window: *Window, flags: Flags) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowFullscreen(window, flags.toInt());
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn getSurface(window: *Window) callconv(.Inline) !*Surface {
        return raw.SDL_GetWindowSurface(window) orelse error.SDL_ERROR;
    }
    pub fn updateSurface(window: *Window) callconv(.Inline) !void {
        const rc = raw.SDL_UpdateWindowSurface(window);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn updateSurfaceRects(window: *Window, rects: []const Rect) callconv(.Inline) !void {
        const rc = raw.SDL_UpdateWindowSurfaceRects(window, rects.ptr, @intCast(i32, rects.len));
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn setGrab(window: *Window, grabbed: bool) callconv(.Inline) void {
        raw.SDL_SetWindowGrab(window, @boolToInt(grabbed));
    }
    pub fn getGrab(window: *Window) callconv(.Inline) bool {
        return raw.SDL_GetWindowGrab(window) != 0;
    }
    pub fn setBrightness(window: *Window, brightness: f32) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowBrightness(window, brightness);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub const getBrightness = raw.SDL_GetWindowBrightness;
    pub fn setOpacity(window: *Window, opacity: f32) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowOpacity(window, opacity);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn getOpacity(window: *Window) callconv(.Inline) !f32 {
        var opacity: f32 = undefined;
        const rc = raw.SDL_GetWindowOpacity(window, &opacity);
        if (rc < 0) return error.SDL_ERROR;
        return opacity;
    }
    pub fn setModalFor(modal_window: *Window, parent_window: *Window) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowModalFor(modal_window, parent_window);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn setInputFocus(window: *Window) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowInputFocus(window);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn setGammaRamp(window: *Window, red: ?*const [256]u16, green: ?*const [256]u16, blue: ?*const [256]u16) callconv(.Inline) !void {
        const rc = raw.SDL_SetWindowGammaRamp(window, red, green, blue);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn getGammaRamp(window: *Window, red: ?*[256]u16, green: ?*[256]u16, blue: ?*[256]u16) callconv(.Inline) !void {
        const rc = raw.SDL_GetWindowGammaRamp(window, red, green, blue);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub fn setHitTest(
        window: *Window,
        comptime DataPtrT: type,
        comptime callback: fn(win: *Window, area: ?*const Point, data: DataPtrT) HitTestResult,
        callback_data: DataPtrT
    ) callconv(.Inline) !void {
        comptime var ptr_info = @typeInfo(DataPtrT);
        if (ptr_info == .Optional) {
            ptr_info = @typeInfo(ptr_info.child);
        }
        if (ptr_info != .Pointer or ptr_info.Pointer.size == .Slice) {
            @compileError("DataPtrT must be a pointer type, but is "++@typeName(DataPtrT));
        }
        if (@sizeOf(DataPtrT) != @sizeOf(?*anyopaque)) {
            @compileError("DataPtrT must be a real pointer, but is "++@typeName(DataPtrT));
        }
        const gen = struct {
            fn hitTestCallback(win: *Window, area: ?*const Point, data: ?*anyopaque) callconv(CC) HitTestResult {
                const ptr = @intToPtr(DataPtrT, @ptrToInt(data));
                return callback(win, area, ptr);
            }
        };
        const erased = @intToPtr(?*anyopaque, @ptrToInt(callback_data));
        const rc = raw.SDL_SetWindowHitTest(window, gen.hitTestCallback, erased);
        if (rc < 0) return error.SDL_ERROR;
    }
};

pub const video = struct {
    pub const DisplayMode = extern struct {
        format: Format,
        w: i32,
        h: i32,
        refresh_rate: i32 = 0,
        driverdata: ?*anyopaque = null,
    };

    pub const WindowEvent = enum(u32) {
        none,
        shown,
        hidden,
        exposed,
        moved,
        resized,
        size_changed,
        minimized,
        maximized,
        restored,
        enter,
        leave,
        focus_gained,
        focus_lost,
        close,
        take_focus,
        hit_test,
        _,
    };

    pub const DisplayEvent = enum(u32) {
        none,
        orientation,
        connected,
        disconnected,
        _,
    };

    pub const DisplayOrientation = enum(u32) {
        unknown,
        landscape,
        landscape_flipped,
        portrait,
        portrait_flipped,
        _,
    };
};

pub const gl = struct {
    pub const Context = *opaque{};
    pub const Attr = enum(u32) {
        RED_SIZE,
        GREEN_SIZE,
        BLUE_SIZE,
        ALPHA_SIZE,
        BUFFER_SIZE,
        DOUBLEBUFFER,
        DEPTH_SIZE,
        STENCIL_SIZE,
        ACCUM_RED_SIZE,
        ACCUM_GREEN_SIZE,
        ACCUM_BLUE_SIZE,
        ACCUM_ALPHA_SIZE,
        STEREO,
        MULTISAMPLEBUFFERS,
        MULTISAMPLESAMPLES,
        ACCELERATED_VISUAL,
        RETAINED_BACKING,
        CONTEXT_MAJOR_VERSION,
        CONTEXT_MINOR_VERSION,
        CONTEXT_EGL,
        CONTEXT_FLAGS,
        CONTEXT_PROFILE_MASK,
        SHARE_WITH_CURRENT_CONTEXT,
        FRAMEBUFFER_SRGB_CAPABLE,
        CONTEXT_RELEASE_BEHAVIOR,
        CONTEXT_RESET_NOTIFICATION,
        CONTEXT_NO_ERROR,
        _,
    };

    pub const Profile = packed struct {
        core: bool = false,
        compatibility: bool = false,
        es: bool = false,
        __pad0: u13 = 0,
    };

    pub const ContextFlags = packed struct {
        debug: bool = false,
        forward_compatible: bool = false,
        robust_access: bool = false,
        reset_isolation: bool = false,
        __pad0: u12 = 0,
    };

    pub const ContextReleaseFlags = packed struct {
        flush: bool = false,
        __pad0: u15 = 0,
    };

    pub const ContextResetNotification = packed struct {
        lose_context: bool = false,
        __pad0: u15 = 0,
    };

    pub const SwapInterval = enum (c_int) {
        late_swaps = -1,
        vsync_off = 0,
        vsync_on = 1,
        _,
    };
};

pub const Scancode = enum (c_int) {
    UNKNOWN = 0,

    A = 4,
    B = 5,
    C = 6,
    D = 7,
    E = 8,
    F = 9,
    G = 10,
    H = 11,
    I = 12,
    J = 13,
    K = 14,
    L = 15,
    M = 16,
    N = 17,
    O = 18,
    P = 19,
    Q = 20,
    R = 21,
    S = 22,
    T = 23,
    U = 24,
    V = 25,
    W = 26,
    X = 27,
    Y = 28,
    Z = 29,

    @"1" = 30,
    @"2" = 31,
    @"3" = 32,
    @"4" = 33,
    @"5" = 34,
    @"6" = 35,
    @"7" = 36,
    @"8" = 37,
    @"9" = 38,
    @"0" = 39,

    RETURN = 40,
    ESCAPE = 41,
    BACKSPACE = 42,
    TAB = 43,
    SPACE = 44,

    MINUS = 45,
    EQUALS = 46,
    LEFTBRACKET = 47,
    RIGHTBRACKET = 48,
    BACKSLASH = 49,
    NONUSHASH = 50,
    SEMICOLON = 51,
    APOSTROPHE = 52,
    GRAVE = 53,
    COMMA = 54,
    PERIOD = 55,
    SLASH = 56,

    CAPSLOCK = 57,

    F1 = 58,
    F2 = 59,
    F3 = 60,
    F4 = 61,
    F5 = 62,
    F6 = 63,
    F7 = 64,
    F8 = 65,
    F9 = 66,
    F10 = 67,
    F11 = 68,
    F12 = 69,

    PRINTSCREEN = 70,
    SCROLLLOCK = 71,
    PAUSE = 72,
    INSERT = 73,
    HOME = 74,
    PAGEUP = 75,
    DELETE = 76,
    END = 77,
    PAGEDOWN = 78,
    RIGHT = 79,
    LEFT = 80,
    DOWN = 81,
    UP = 82,

    NUMLOCKCLEAR = 83,
    KP_DIVIDE = 84,
    KP_MULTIPLY = 85,
    KP_MINUS = 86,
    KP_PLUS = 87,
    KP_ENTER = 88,
    KP_1 = 89,
    KP_2 = 90,
    KP_3 = 91,
    KP_4 = 92,
    KP_5 = 93,
    KP_6 = 94,
    KP_7 = 95,
    KP_8 = 96,
    KP_9 = 97,
    KP_0 = 98,
    KP_PERIOD = 99,

    NONUSBACKSLASH = 100,
    APPLICATION = 101,
    POWER = 102,
    KP_EQUALS = 103,
    F13 = 104,
    F14 = 105,
    F15 = 106,
    F16 = 107,
    F17 = 108,
    F18 = 109,
    F19 = 110,
    F20 = 111,
    F21 = 112,
    F22 = 113,
    F23 = 114,
    F24 = 115,
    EXECUTE = 116,
    HELP = 117,
    MENU = 118,
    SELECT = 119,
    STOP = 120,
    AGAIN = 121,
    UNDO = 122,
    CUT = 123,
    COPY = 124,
    PASTE = 125,
    FIND = 126,
    MUTE = 127,
    VOLUMEUP = 128,
    VOLUMEDOWN = 129,
    KP_COMMA = 133,
    KP_EQUALSAS400 = 134,

    INTERNATIONAL1 = 135,
    INTERNATIONAL2 = 136,
    INTERNATIONAL3 = 137,
    INTERNATIONAL4 = 138,
    INTERNATIONAL5 = 139,
    INTERNATIONAL6 = 140,
    INTERNATIONAL7 = 141,
    INTERNATIONAL8 = 142,
    INTERNATIONAL9 = 143,
    LANG1 = 144,
    LANG2 = 145,
    LANG3 = 146,
    LANG4 = 147,
    LANG5 = 148,
    LANG6 = 149,
    LANG7 = 150,
    LANG8 = 151,
    LANG9 = 152,

    ALTERASE = 153,
    SYSREQ = 154,
    CANCEL = 155,
    CLEAR = 156,
    PRIOR = 157,
    RETURN2 = 158,
    SEPARATOR = 159,
    OUT = 160,
    OPER = 161,
    CLEARAGAIN = 162,
    CRSEL = 163,
    EXSEL = 164,

    KP_00 = 176,
    KP_000 = 177,
    THOUSANDSSEPARATOR = 178,
    DECIMALSEPARATOR = 179,
    CURRENCYUNIT = 180,
    CURRENCYSUBUNIT = 181,
    KP_LEFTPAREN = 182,
    KP_RIGHTPAREN = 183,
    KP_LEFTBRACE = 184,
    KP_RIGHTBRACE = 185,
    KP_TAB = 186,
    KP_BACKSPACE = 187,
    KP_A = 188,
    KP_B = 189,
    KP_C = 190,
    KP_D = 191,
    KP_E = 192,
    KP_F = 193,
    KP_XOR = 194,
    KP_POWER = 195,
    KP_PERCENT = 196,
    KP_LESS = 197,
    KP_GREATER = 198,
    KP_AMPERSAND = 199,
    KP_DBLAMPERSAND = 200,
    KP_VERTICALBAR = 201,
    KP_DBLVERTICALBAR = 202,
    KP_COLON = 203,
    KP_HASH = 204,
    KP_SPACE = 205,
    KP_AT = 206,
    KP_EXCLAM = 207,
    KP_MEMSTORE = 208,
    KP_MEMRECALL = 209,
    KP_MEMCLEAR = 210,
    KP_MEMADD = 211,
    KP_MEMSUBTRACT = 212,
    KP_MEMMULTIPLY = 213,
    KP_MEMDIVIDE = 214,
    KP_PLUSMINUS = 215,
    KP_CLEAR = 216,
    KP_CLEARENTRY = 217,
    KP_BINARY = 218,
    KP_OCTAL = 219,
    KP_DECIMAL = 220,
    KP_HEXADECIMAL = 221,

    LCTRL = 224,
    LSHIFT = 225,
    LALT = 226,
    LGUI = 227,
    RCTRL = 228,
    RSHIFT = 229,
    RALT = 230,
    RGUI = 231,

    MODE = 257,

    AUDIONEXT = 258,
    AUDIOPREV = 259,
    AUDIOSTOP = 260,
    AUDIOPLAY = 261,
    AUDIOMUTE = 262,
    MEDIASELECT = 263,
    WWW = 264,
    MAIL = 265,
    CALCULATOR = 266,
    COMPUTER = 267,
    AC_SEARCH = 268,
    AC_HOME = 269,
    AC_BACK = 270,
    AC_FORWARD = 271,
    AC_STOP = 272,
    AC_REFRESH = 273,
    AC_BOOKMARKS = 274,

    BRIGHTNESSDOWN = 275,
    BRIGHTNESSUP = 276,
    DISPLAYSWITCH = 277,
    KBDILLUMTOGGLE = 278,
    KBDILLUMDOWN = 279,
    KBDILLUMUP = 280,
    EJECT = 281,
    SLEEP = 282,

    APP1 = 283,
    APP2 = 284,

    AUDIOREWIND = 285,
    AUDIOFASTFORWARD = 286,

    NUM_SCANCODES = 512,

    _,
};

pub const Keycode = enum (i32) {
    UNKNOWN = 0,

    RETURN = '\r',
    ESCAPE = '\x1b',
    BACKSPACE = '\x08',
    TAB = '\t',
    SPACE = ' ',
    EXCLAIM = '!',
    QUOTEDBL = '"',
    HASH = '#',
    PERCENT = '%',
    DOLLAR = '$',
    AMPERSAND = '&',
    QUOTE = '\'',
    LEFTPAREN = '(',
    RIGHTPAREN = ')',
    ASTERISK = '*',
    PLUS = '+',
    COMMA = ',',
    MINUS = '-',
    PERIOD = '.',
    SLASH = '/',
    @"0" = '0',
    @"1" = '1',
    @"2" = '2',
    @"3" = '3',
    @"4" = '4',
    @"5" = '5',
    @"6" = '6',
    @"7" = '7',
    @"8" = '8',
    @"9" = '9',
    COLON = ':',
    SEMICOLON = ';',
    LESS = '<',
    EQUALS = '=',
    GREATER = '>',
    QUESTION = '?',
    AT = '@',

    LEFTBRACKET = '[',
    BACKSLASH = '\\',
    RIGHTBRACKET = ']',
    CARET = '^',
    UNDERSCORE = '_',
    BACKQUOTE = '`',
    a = 'a',
    b = 'b',
    c = 'c',
    d = 'd',
    e = 'e',
    f = 'f',
    g = 'g',
    h = 'h',
    i = 'i',
    j = 'j',
    k = 'k',
    l = 'l',
    m = 'm',
    n = 'n',
    o = 'o',
    p = 'p',
    q = 'q',
    r = 'r',
    s = 's',
    t = 't',
    u = 'u',
    v = 'v',
    w = 'w',
    x = 'x',
    y = 'y',
    z = 'z',

    CAPSLOCK = intValueFromScancode(.CAPSLOCK),

    F1 = intValueFromScancode(.F1),
    F2 = intValueFromScancode(.F2),
    F3 = intValueFromScancode(.F3),
    F4 = intValueFromScancode(.F4),
    F5 = intValueFromScancode(.F5),
    F6 = intValueFromScancode(.F6),
    F7 = intValueFromScancode(.F7),
    F8 = intValueFromScancode(.F8),
    F9 = intValueFromScancode(.F9),
    F10 = intValueFromScancode(.F10),
    F11 = intValueFromScancode(.F11),
    F12 = intValueFromScancode(.F12),

    PRINTSCREEN = intValueFromScancode(.PRINTSCREEN),
    SCROLLLOCK = intValueFromScancode(.SCROLLLOCK),
    PAUSE = intValueFromScancode(.PAUSE),
    INSERT = intValueFromScancode(.INSERT),
    HOME = intValueFromScancode(.HOME),
    PAGEUP = intValueFromScancode(.PAGEUP),
    DELETE = '\x7f',
    END = intValueFromScancode(.END),
    PAGEDOWN = intValueFromScancode(.PAGEDOWN),
    RIGHT = intValueFromScancode(.RIGHT),
    LEFT = intValueFromScancode(.LEFT),
    DOWN = intValueFromScancode(.DOWN),
    UP = intValueFromScancode(.UP),

    NUMLOCKCLEAR = intValueFromScancode(.NUMLOCKCLEAR),
    KP_DIVIDE = intValueFromScancode(.KP_DIVIDE),
    KP_MULTIPLY = intValueFromScancode(.KP_MULTIPLY),
    KP_MINUS = intValueFromScancode(.KP_MINUS),
    KP_PLUS = intValueFromScancode(.KP_PLUS),
    KP_ENTER = intValueFromScancode(.KP_ENTER),
    KP_1 = intValueFromScancode(.KP_1),
    KP_2 = intValueFromScancode(.KP_2),
    KP_3 = intValueFromScancode(.KP_3),
    KP_4 = intValueFromScancode(.KP_4),
    KP_5 = intValueFromScancode(.KP_5),
    KP_6 = intValueFromScancode(.KP_6),
    KP_7 = intValueFromScancode(.KP_7),
    KP_8 = intValueFromScancode(.KP_8),
    KP_9 = intValueFromScancode(.KP_9),
    KP_0 = intValueFromScancode(.KP_0),
    KP_PERIOD = intValueFromScancode(.KP_PERIOD),

    APPLICATION = intValueFromScancode(.APPLICATION),
    POWER = intValueFromScancode(.POWER),
    KP_EQUALS = intValueFromScancode(.KP_EQUALS),
    F13 = intValueFromScancode(.F13),
    F14 = intValueFromScancode(.F14),
    F15 = intValueFromScancode(.F15),
    F16 = intValueFromScancode(.F16),
    F17 = intValueFromScancode(.F17),
    F18 = intValueFromScancode(.F18),
    F19 = intValueFromScancode(.F19),
    F20 = intValueFromScancode(.F20),
    F21 = intValueFromScancode(.F21),
    F22 = intValueFromScancode(.F22),
    F23 = intValueFromScancode(.F23),
    F24 = intValueFromScancode(.F24),
    EXECUTE = intValueFromScancode(.EXECUTE),
    HELP = intValueFromScancode(.HELP),
    MENU = intValueFromScancode(.MENU),
    SELECT = intValueFromScancode(.SELECT),
    STOP = intValueFromScancode(.STOP),
    AGAIN = intValueFromScancode(.AGAIN),
    UNDO = intValueFromScancode(.UNDO),
    CUT = intValueFromScancode(.CUT),
    COPY = intValueFromScancode(.COPY),
    PASTE = intValueFromScancode(.PASTE),
    FIND = intValueFromScancode(.FIND),
    MUTE = intValueFromScancode(.MUTE),
    VOLUMEUP = intValueFromScancode(.VOLUMEUP),
    VOLUMEDOWN = intValueFromScancode(.VOLUMEDOWN),
    KP_COMMA = intValueFromScancode(.KP_COMMA),
    KP_EQUALSAS400 = intValueFromScancode(.KP_EQUALSAS400),

    ALTERASE = intValueFromScancode(.ALTERASE),
    SYSREQ = intValueFromScancode(.SYSREQ),
    CANCEL = intValueFromScancode(.CANCEL),
    CLEAR = intValueFromScancode(.CLEAR),
    PRIOR = intValueFromScancode(.PRIOR),
    RETURN2 = intValueFromScancode(.RETURN2),
    SEPARATOR = intValueFromScancode(.SEPARATOR),
    OUT = intValueFromScancode(.OUT),
    OPER = intValueFromScancode(.OPER),
    CLEARAGAIN = intValueFromScancode(.CLEARAGAIN),
    CRSEL = intValueFromScancode(.CRSEL),
    EXSEL = intValueFromScancode(.EXSEL),

    KP_00 = intValueFromScancode(.KP_00),
    KP_000 = intValueFromScancode(.KP_000),
    THOUSANDSSEPARATOR = intValueFromScancode(.THOUSANDSSEPARATOR),
    DECIMALSEPARATOR = intValueFromScancode(.DECIMALSEPARATOR),
    CURRENCYUNIT = intValueFromScancode(.CURRENCYUNIT),
    CURRENCYSUBUNIT = intValueFromScancode(.CURRENCYSUBUNIT),
    KP_LEFTPAREN = intValueFromScancode(.KP_LEFTPAREN),
    KP_RIGHTPAREN = intValueFromScancode(.KP_RIGHTPAREN),
    KP_LEFTBRACE = intValueFromScancode(.KP_LEFTBRACE),
    KP_RIGHTBRACE = intValueFromScancode(.KP_RIGHTBRACE),
    KP_TAB = intValueFromScancode(.KP_TAB),
    KP_BACKSPACE = intValueFromScancode(.KP_BACKSPACE),
    KP_A = intValueFromScancode(.KP_A),
    KP_B = intValueFromScancode(.KP_B),
    KP_C = intValueFromScancode(.KP_C),
    KP_D = intValueFromScancode(.KP_D),
    KP_E = intValueFromScancode(.KP_E),
    KP_F = intValueFromScancode(.KP_F),
    KP_XOR = intValueFromScancode(.KP_XOR),
    KP_POWER = intValueFromScancode(.KP_POWER),
    KP_PERCENT = intValueFromScancode(.KP_PERCENT),
    KP_LESS = intValueFromScancode(.KP_LESS),
    KP_GREATER = intValueFromScancode(.KP_GREATER),
    KP_AMPERSAND = intValueFromScancode(.KP_AMPERSAND),
    KP_DBLAMPERSAND = intValueFromScancode(.KP_DBLAMPERSAND),
    KP_VERTICALBAR = intValueFromScancode(.KP_VERTICALBAR),
    KP_DBLVERTICALBAR = intValueFromScancode(.KP_DBLVERTICALBAR),
    KP_COLON = intValueFromScancode(.KP_COLON),
    KP_HASH = intValueFromScancode(.KP_HASH),
    KP_SPACE = intValueFromScancode(.KP_SPACE),
    KP_AT = intValueFromScancode(.KP_AT),
    KP_EXCLAM = intValueFromScancode(.KP_EXCLAM),
    KP_MEMSTORE = intValueFromScancode(.KP_MEMSTORE),
    KP_MEMRECALL = intValueFromScancode(.KP_MEMRECALL),
    KP_MEMCLEAR = intValueFromScancode(.KP_MEMCLEAR),
    KP_MEMADD = intValueFromScancode(.KP_MEMADD),
    KP_MEMSUBTRACT = intValueFromScancode(.KP_MEMSUBTRACT),
    KP_MEMMULTIPLY = intValueFromScancode(.KP_MEMMULTIPLY),
    KP_MEMDIVIDE = intValueFromScancode(.KP_MEMDIVIDE),
    KP_PLUSMINUS = intValueFromScancode(.KP_PLUSMINUS),
    KP_CLEAR = intValueFromScancode(.KP_CLEAR),
    KP_CLEARENTRY = intValueFromScancode(.KP_CLEARENTRY),
    KP_BINARY = intValueFromScancode(.KP_BINARY),
    KP_OCTAL = intValueFromScancode(.KP_OCTAL),
    KP_DECIMAL = intValueFromScancode(.KP_DECIMAL),
    KP_HEXADECIMAL = intValueFromScancode(.KP_HEXADECIMAL),

    LCTRL = intValueFromScancode(.LCTRL),
    LSHIFT = intValueFromScancode(.LSHIFT),
    LALT = intValueFromScancode(.LALT),
    LGUI = intValueFromScancode(.LGUI),
    RCTRL = intValueFromScancode(.RCTRL),
    RSHIFT = intValueFromScancode(.RSHIFT),
    RALT = intValueFromScancode(.RALT),
    RGUI = intValueFromScancode(.RGUI),

    MODE = intValueFromScancode(.MODE),

    AUDIONEXT = intValueFromScancode(.AUDIONEXT),
    AUDIOPREV = intValueFromScancode(.AUDIOPREV),
    AUDIOSTOP = intValueFromScancode(.AUDIOSTOP),
    AUDIOPLAY = intValueFromScancode(.AUDIOPLAY),
    AUDIOMUTE = intValueFromScancode(.AUDIOMUTE),
    MEDIASELECT = intValueFromScancode(.MEDIASELECT),
    WWW = intValueFromScancode(.WWW),
    MAIL = intValueFromScancode(.MAIL),
    CALCULATOR = intValueFromScancode(.CALCULATOR),
    COMPUTER = intValueFromScancode(.COMPUTER),
    AC_SEARCH = intValueFromScancode(.AC_SEARCH),
    AC_HOME = intValueFromScancode(.AC_HOME),
    AC_BACK = intValueFromScancode(.AC_BACK),
    AC_FORWARD = intValueFromScancode(.AC_FORWARD),
    AC_STOP = intValueFromScancode(.AC_STOP),
    AC_REFRESH = intValueFromScancode(.AC_REFRESH),
    AC_BOOKMARKS = intValueFromScancode(.AC_BOOKMARKS),

    BRIGHTNESSDOWN = intValueFromScancode(.BRIGHTNESSDOWN),
    BRIGHTNESSUP = intValueFromScancode(.BRIGHTNESSUP),
    DISPLAYSWITCH = intValueFromScancode(.DISPLAYSWITCH),
    KBDILLUMTOGGLE = intValueFromScancode(.KBDILLUMTOGGLE),
    KBDILLUMDOWN = intValueFromScancode(.KBDILLUMDOWN),
    KBDILLUMUP = intValueFromScancode(.KBDILLUMUP),
    EJECT = intValueFromScancode(.EJECT),
    SLEEP = intValueFromScancode(.SLEEP),
    APP1 = intValueFromScancode(.APP1),
    APP2 = intValueFromScancode(.APP2),

    AUDIOREWIND = intValueFromScancode(.AUDIOREWIND),
    AUDIOFASTFORWARD = intValueFromScancode(.AUDIOFASTFORWARD),

    _,

    pub fn intValueFromScancode(code: Scancode) i32 {
        return @intCast(i32, @enumToInt(code)) | (1<<30);
    }
};

pub const Keymod = packed struct {
    lshift: bool = false,
    rshift: bool = false,
    __pad0: u4 = 0,
    lctrl: bool = false,
    rctrl: bool = false,

    lalt: bool = false,
    ralt: bool = false,
    lgui: bool = false,
    rgui: bool = false,
    num: bool = false,
    caps: bool = false,
    mode: bool = false,
    reserved: bool = false,

    pub fn ctrl(self: Keymod) bool {
        return self.lctrl or self.rctrl;
    }
    pub fn shift(self: Keymod) bool {
        return self.lshift or self.rshift;
    }
    pub fn alt(self: Keymod) bool {
        return self.lalt or self.ralt;
    }
    pub fn gui(self: Keymod) bool {
        return self.lgui or self.rgui;
    }

    pub fn fromInt(int: KeymodInt) Keymod {
        return @bitCast(Keymod, int);
    }
    pub fn toInt(self: Keymod) KeymodInt {
        return @bitCast(KeymodInt, self);
    }
};

pub const KeymodInt = u16;

pub const Keysym = extern struct {
    scancode: Scancode,
    sym: Keycode,
    mod: Keymod align(2),
    unused: u32 = 0,
};

pub const Joystick = opaque {
    pub const GUID = extern struct {
        data: [16]u8,
    };
    pub const ID = enum(i32) { invalid = -1, _ };

    pub const Type = enum(u32) {
        unknown,
        gamecontroller,
        wheel,
        arcade_stick,
        flight_stick,
        dance_pad,
        guitar,
        drum_kit,
        arcade_pad,
        throttle,
        _,
    };

    pub const PowerLevel = enum(i32) {
        unknown = -1,
        empty,
        low,
        medium,
        full,
        wired,
        max,
        _,
    };

    pub const IPHONE_MAX_GFORCE = 5.0;

    pub const AXIS_MAX = 32767;
    pub const AXIS_MIN = -32768;

    pub const Hat = enum (u8) {
        centered = 0,
        up = 1,
        right = 2,
        down = 4,
        left = 8,
        rightup = 3,
        rightdown = 6,
        leftup = 9,
        leftdown = 12,
        _,

        pub fn hasLeft(self: Hat) bool {
            return @enumToInt(self) & @enumToInt(Hat.left) != 0; 
        }
        pub fn hasRight(self: Hat) bool {
            return @enumToInt(self) & @enumToInt(Hat.right) != 0; 
        }
        pub fn hasUp(self: Hat) bool {
            return @enumToInt(self) & @enumToInt(Hat.up) != 0; 
        }
        pub fn hasDown(self: Hat) bool {
            return @enumToInt(self) & @enumToInt(Hat.down) != 0; 
        }
    };
};

pub const TouchID = enum(i64) { mouse = -1, _ };
pub const FingerID = enum(i64) { _ };
pub const TouchDeviceType = enum (i32) {
    invalid = -1,
    direct,
    indirect_absolute,
    indirect_relative,
    _,
};
pub const Finger = struct {
    id: FingerID,
    x: f32,
    y: f32,
    pressure: f32,
};
pub const TOUCH_MOUSEID = ~@as(u32, 0);

pub const GestureID = enum(i64) { _ };

pub const Event = extern union {
    type: Type,
    common: CommonEvent,
    display: DisplayEvent,
    window: WindowEvent,
    key: KeyboardEvent,
    edit: TextEditingEvent,
    text: TextInputEvent,
    motion: MouseMotionEvent,
    button: MouseButtonEvent,
    wheel: MouseWheelEvent,
    jaxis: JoyAxisEvent,
    jball: JoyBallEvent,
    jhat: JoyHatEvent,
    jbutton: JoyButtonEvent,
    jdevice: JoyDeviceEvent,
    caxis: ControllerAxisEvent,
    cbutton: ControllerButtonEvent,
    cdevice: ControllerDeviceEvent,
    ctouchpad: ControllerTouchpadEvent,
    csensor: ControllerSensorEvent,
    adevice: AudioDeviceEvent,
    sensor: SensorEvent,
    quit: QuitEvent,
    user: UserEvent,
    syswm: SysWMEvent,
    tfinger: TouchFingerEvent,
    mgesture: MultiGestureEvent,
    dgesture: DollarGestureEvent,
    drop: DropEvent,
    padding: [56]u8,

    pub const Type = enum(u32) {
        FIRSTEVENT     = 0,

        QUIT           = 0x100,

        APP_TERMINATING,
        APP_LOWMEMORY,
        APP_WILLENTERBACKGROUND,
        APP_DIDENTERBACKGROUND,
        APP_WILLENTERFOREGROUND,
        APP_DIDENTERFOREGROUND,

        LOCALECHANGED,

        DISPLAYEVENT   = 0x150,

        WINDOWEVENT    = 0x200,
        SYSWMEVENT,

        KEYDOWN        = 0x300,
        KEYUP,
        TEXTEDITING,
        TEXTINPUT,
        KEYMAPCHANGED,

        MOUSEMOTION    = 0x400,
        MOUSEBUTTONDOWN,
        MOUSEBUTTONUP,
        MOUSEWHEEL,

        JOYAXISMOTION  = 0x600,
        JOYBALLMOTION,
        JOYHATMOTION,
        JOYBUTTONDOWN,
        JOYBUTTONUP,
        JOYDEVICEADDED,
        JOYDEVICEREMOVED,

        CONTROLLERAXISMOTION  = 0x650,
        CONTROLLERBUTTONDOWN,
        CONTROLLERBUTTONUP,
        CONTROLLERDEVICEADDED,
        CONTROLLERDEVICEREMOVED,
        CONTROLLERDEVICEREMAPPED,
        CONTROLLERTOUCHPADDOWN,
        CONTROLLERTOUCHPADMOTION,
        CONTROLLERTOUCHPADUP,
        CONTROLLERSENSORUPDATE,

        FINGERDOWN      = 0x700,
        FINGERUP,
        FINGERMOTION,

        DOLLARGESTURE   = 0x800,
        DOLLARRECORD,
        MULTIGESTURE,

        CLIPBOARDUPDATE = 0x900,

        DROPFILE        = 0x1000,
        DROPTEXT,
        DROPBEGIN,
        DROPCOMPLETE,

        AUDIODEVICEADDED = 0x1100,
        AUDIODEVICEREMOVED,

        SENSORUPDATE = 0x1200,

        RENDER_TARGETS_RESET = 0x2000,
        RENDER_DEVICE_RESET,

        USEREVENT    = 0x8000,

        LASTEVENT    = 0xFFFF,

        _,
    };

    pub const CommonEvent = extern struct {
        type: Type,
        timestamp: u32,
    };

    pub const DisplayEvent = extern struct {
        type: Type,
        timestamp: u32,
        display: u32,
        event: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
        data1: i32,
    };

    pub const WindowEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        event: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
        data1: i32,
        data2: i32,
    };
    
    pub const KeyboardEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        state: u8,
        repeat: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
        keysym: Keysym,
    };

    pub const TEXTEDITINGEVENT_TEXT_SIZE = 32;
    pub const TextEditingEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        text: [TEXTEDITINGEVENT_TEXT_SIZE]u8,
        start: i32,
        length: i32,
    };

    pub const TEXTINPUTEVENT_TEXT_SIZE = 32;
    pub const TextInputEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        text: [TEXTINPUTEVENT_TEXT_SIZE]u8,
    };

    pub const MouseMotionEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        which: u32,
        state: u32,
        x: i32,
        y: i32,
        xrel: i32,
        yrel: i32,
    };

    pub const MouseButtonEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        which: u32,
        button: u8,
        state: u8,
        clicks: u8,
        padding1: u8 = 0,
        x: i32,
        y: i32,
    };

    pub const MouseWheelEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        which: u32,
        x: i32,
        y: i32,
        direction: u32,
    };

    pub const JoyAxisEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        axis: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
        value: i16,
        padding4: u16 = 0,
    };

    pub const JoyBallEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        ball: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
        xrel: i16,
        yrel: i16,
    };

    pub const JoyHatEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        hat: u8,
        value: Joystick.Hat,
        padding2: u8 = 0,
        padding3: u8 = 0,
    };

    pub const JoyButtonEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        button: u8,
        state: u8,
        padding2: u8 = 0,
        padding3: u8 = 0,
    };

    pub const JoyDeviceEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: i32,
    };

    pub const ControllerAxisEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        axis: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
        value: i16,
        padding4: u16 = 0,
    };

    pub const ControllerButtonEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        button: u8,
        state: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
    };

    pub const ControllerDeviceEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: i32,
    };

    pub const ControllerTouchpadEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        touchpad: i32,
        finger: i32,
        x: f32,
        y: f32,
        pressure: f32,
    };

    pub const ControllerSensorEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: Joystick.ID,
        sensor: i32,
        data: [3]f32,
    };

    pub const AudioDeviceEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: u32,
        iscapture: u8,
        padding1: u8 = 0,
        padding2: u8 = 0,
        padding3: u8 = 0,
    };

    pub const TouchFingerEvent = extern struct {
        type: Type,
        timestamp: u32,
        touchId: TouchID,
        fingerId: FingerID,
        x: f32,
        y: f32,
        dx: f32,
        dy: f32,
        pressure: f32,
        windowID: u32,
    };

    pub const MultiGestureEvent = extern struct {
        type: Type,
        timestamp: u32,
        touchId: TouchID,
        dTheta: f32,
        dDist: f32,
        x: f32,
        y: f32,
        numFingers: u16,
        padding: u16 = 0,
    };

    pub const DollarGestureEvent = extern struct {
        type: Type,
        timestamp: u32,
        touchId: TouchID,
        gestureId: GestureID,
        numFingers: u32,
        @"error": f32,
        x: f32,
        y: f32,
    };

    pub const DropEvent = extern struct {
        type: Type,
        timestamp: u32,
        file: ?[*:0]u8,
        windowID: u32,
    };

    pub const SensorEvent = extern struct {
        type: Type,
        timestamp: u32,
        which: i32,
        data: [6]f32,
    };

    pub const QuitEvent = extern struct {
        type: Type,
        timestamp: u32,
    };

    pub const OSEvent = extern struct {
        type: Type,
        timestamp: u32,
    };

    pub const UserEvent = extern struct {
        type: Type,
        timestamp: u32,
        windowID: u32,
        code: i32,
        data1: ?*anyopaque,
        data2: ?*anyopaque,
    };

    pub const SysWMEvent = extern struct {
        type: Type,
        timestamp: u32,
        msg: ?*SysWMmsg,
    };

    pub const Action = enum(u32) {
        add,
        peek,
        get,
        _,
    };

    pub const State = enum(i32) {
        query = -1,
        ignore = 0,
        disable = 0,
        enable = 1,
        _,
    };

    pub const Filter = fn(userdata: ?*anyopaque, event: *Event) callconv(CC) IntBool;

    comptime {
        if (@sizeOf(Event) != 56)
            @compileError("sdl.Event must be exactly 56 bytes");
    }
};

pub const vulkan = struct {
    pub fn loadLibrary(path: ?[*:0]const u8) callconv(.Inline) !void {
        const rc = raw.SDL_Vulkan_LoadLibrary(path);
        if (rc < 0) return error.SDL_ERROR;
    }
    pub const unloadLibrary = raw.SDL_Vulkan_UnloadLibrary;
    pub fn getVkGetInstanceProcAddr() callconv(.Inline) !@TypeOf(vk.vkGetInstanceProcAddr) {
        const ptr = raw.SDL_Vulkan_GetVkGetInstanceProcAddr();
        if (ptr == null) return error.SDL_ERROR;
        return @ptrCast(@TypeOf(vk.vkGetInstanceProcAddr), ptr.?);
    }

    pub fn getInstanceExtensionsCount(window: *Window) !u32 {
        var count: u32 = 0;
        const rc = raw.SDL_Vulkan_GetInstanceExtensions(window, &count, null);
        if (rc == 0) return error.SDL_ERROR;
        return count;
    }
    pub fn getInstanceExtensions(window: *Window, buf: [][*:0]const u8) ![][*:0]const u8 {
        var count: u32 = @intCast(u32, buf.len);
        const rc = raw.SDL_Vulkan_GetInstanceExtensions(window, &count, buf.ptr);
        if (rc == 0) return error.SDL_ERROR;
        return buf[0..count];
    }
    pub fn getInstanceExtensionsAlloc(window: *Window, allocator: *std.mem.Allocator) ![][*:0]const u8 {
        var count: u32 = 0;
        var rc = raw.SDL_Vulkan_GetInstanceExtensions(window, &count, null);
        if (rc == 0) return error.SDL_ERROR;

        var buf = try allocator.alloc([*:0]const u8, count);
        errdefer allocator.free(buf);

        rc = raw.SDL_Vulkan_GetInstanceExtensions(window, &count, buf.ptr);
        if (rc == 0) return error.SDL_ERROR;

        if (count < buf.len) {
            buf = allocator.shrink(buf, count);
        }
        return buf;
    }

    pub fn createSurface(window: *Window, instance: vk.Instance) callconv(.Inline) !vk.SurfaceKHR {
        var surface: vk.SurfaceKHR = undefined;
        const rc = raw.SDL_Vulkan_CreateSurface(window, instance, &surface);
        if (rc == 0) return error.SDL_ERROR;
        return surface;
    }
    pub fn getDrawableSize(window: *Window) callconv(.Inline) Point {
        var p: Point = undefined;
        raw.SDL_Vulkan_GetDrawableSize(window, &p.x, &p.y);
        return p;
    }
};

pub const SysWMType = enum(u32) {
    unknown,
    windows,
    x11,
    directfb,
    cocoa,
    uikit,
    wayland,
    mir,
    winrt,
    android,
    vivante,
    os2,
    haiku,
    _,
};
pub const SysWMmsg = extern struct {
    version: Version = sdl.version,
    subsystem: SysWMType,
    msg: extern union {
        win: Windows,
        x11: X11,
        dfb: DFB,
        cocoa: Cocoa,
        uikit: UiKit,
        vivante: Vivante,
        os2: Os2,
    },

    const BackendNotSupported = extern struct { not_supported: i32 };

    const _Windows = extern struct {
        const w = std.os.windows;
        hwnd: w.HWND,
        msg: w.UINT,
        wParam: w.WPARAM,
        lParam: w.LPARAM,
    };
    pub const Windows = _Windows;

    const _X11 = extern struct {
        const x = @compileError("TODO: IMPORT_X11");
        event: x.XEvent,
    };
    // TODO: X11 support
    pub const X11 = BackendNotSupported;

    const _DFB = extern struct {
        const dfb = @compileError("TODO: IMPORT_DIRECTFB");
        event: dfb.DFBEvent,
    };
    // TODO: DFB support
    pub const DFB = BackendNotSupported;

    const _Cocoa = extern struct {
        dummy: i32,
    };
    pub const Cocoa = _Cocoa;

    const _UiKit = extern struct {
        dummy: i32,
    };
    pub const UiKit = _UiKit;

    const _Vivante = extern struct {
        dummy: i32,
    };
    pub const Vivante = _Vivante;

    const _Os2 = extern struct {
        const os2 = @compileError("TODO: IMPORT_OS2");
        fFrame: os2.BOOL,
        hwnd: os2.HWND,
        msg: os2.ULONG,
        mp1: os2.MPARAM,
        mp2: os2.MPARAM,
    };
    // TODO: Os2 support
    pub const Os2 = BackendNotSupported;
};

pub const SysWMinfo = extern struct {
    version: Version = sdl.version,
    subsystem: SysWMType,
    msg: Message,

    pub const Message = extern union {
        win: Windows,
        winrt: WinRT,
        x11: X11,
        dfb: DFB,
        cocoa: Cocoa,
        uikit: UiKit,
        wl: Wayland,
        mir: Mir,
        android: Android,
        os2: Os2,
        vivante: Vivante,
        dummy: [64]u8,
    };

    comptime {
        if (@sizeOf(Message) != 64) 
            @compileError("Binary compatibility broken, SysWMinfo.Message must be 64 bits");
    }

    const BackendNotSupported = extern struct { not_supported: i32 };

    const _Windows = extern struct {
        const w = std.os.windows;

        windows: ?w.HWND,
        hdc: ?w.HDC,
        hinstance: ?w.HINSTANCE,
    };
    pub const Windows = _Windows;

    const _WinRT = extern struct {
        const wrt = @compileError("TODO: IMPORT_WINRT");
        window: ?*wrt.IInspectable,
    };
    // TODO: WinRT support
    pub const WinRT = BackendNotSupported;

    const _X11 = extern struct {
        const x = @compileError("TODO: IMPORT_X11");
        display: ?*x.Display,
        window: x.Window,
    };
    // TODO: X11 support
    pub const X11 = BackendNotSupported;

    const _DFB = extern struct {
        const dfb = @compileError("TODO: IMPORT_DIRECTFB");
        dfb: ?*dfb.IDirectFB,
        window: ?*dfb.IDirectFBWindow,
        surface: ?*dfb.IDirectFBSurface,
    };
    // TODO: DFB support
    pub const DFB = BackendNotSupported;

    const _Cocoa = extern struct {
        const ns = @compileError("TODO IMPORT COCOA");
        window: ?*ns.NSWindow,
    };
    // TODO: Cocoa support
    pub const Cocoa = BackendNotSupported;

    const _UiKit = extern struct {
        const uk = @compileError("TODO: IMPORT_UIKIT");
        const ogl = @compileError("TODO: IMPORT_GL");
        window: ?*uk.UIWindow,
        framebuffer: ogl.GLuint,
        colorbuffer: ogl.GLuint,
        resolveFramebuffer: ogl.GLuint,
    };
    // TODO: UiKit support
    pub const UiKit = BackendNotSupported;

    const _Wayland = extern struct {
        const wl = @compileError("TODO: IMPORT_WAYLAND");
        display: ?*wl.wl_display,
        surface: ?*wl.wl_surface,
        shell_surface: ?*wl.wl_shell_surface,
    };
    // TODO: Wayland support
    pub const Wayland = BackendNotSupported;

    pub const _Mir = extern struct {
        connection: ?*anyopaque,
        surface: ?*anyopaque,
    };
    pub const Mir = _Mir;

    pub const _Android = extern struct {
        const ad = @compileError("TODO: IMPORT_ANDROID");
        const egl = @compileError("TODO: IMPORT_EGL");
        window: ?*ad.ANativeWindow,
        surface: egl.EGLSurface,
    };
    // TODO: Android support
    pub const Android = BackendNotSupported;

    const _Os2 = extern struct {
        const os2 = @compileError("TODO: IMPORT_OS2");
        hwnd: os2.HWND,
        hwndFrame: os2.HWND,
    };
    // TODO: Os2 support
    pub const Os2 = BackendNotSupported;

    const _Vivante = extern struct {
        const egl = @compileError("TODO: IMPORT_EGL");
        display: egl.EGLNativeDisplayType,
        window: egl.EGLNativeWindowType,
    };
    // TODO: Vivante support
    pub const Vivante = BackendNotSupported;
};


pub const Version = extern struct {
    major: u8,
    minor: u8,
    patch: u8,

    pub fn num(self: @This()) u32 {
        return @as(u32, self.major) * 1000 +
               @as(u32, self.minor) *  100 +
               @as(u32, self.patch);
    }
};
pub const version: Version = .{
    .major = 2,
    .minor = 0,
    .patch = 14,
};


pub const TimerID = enum (c_int) { invalid = 0, _ };
pub const TimerCallback = fn(interval: u32, param: ?*anyopaque) callconv(CC) u32;

pub const getTicks = raw.SDL_GetTicks;

pub const pumpEvents = raw.SDL_PumpEvents;
pub fn peepEvents(buf: []Event, action: Event.Action, minType: Event.Type, maxType: Event.Type) callconv(.Inline) ![]Event {
    const rc = raw.SDL_PeepEvents(buf.ptr, @intCast(i32, buf.len), action, minType, maxType);
    if (rc < 0) return error.SDL_ERROR;
    return buf[0..@intCast(u32, rc)];
}
pub fn hasEvent(@"type": Event.Type) callconv(.Inline) bool {
    return raw.SDL_HasEvent(@"type") != 0;
}
pub fn hasEvents(minType: Event.Type, maxType: Event.Type) callconv(.Inline) bool {
    return raw.SDL_HasEvents(minType, maxType) != 0;
}
pub const flushEvent = raw.SDL_FlushEvent;
pub const flushEvents = raw.SDL_FlushEvents;
pub fn pollEvent() callconv(.Inline) ?Event {
    var e: Event = undefined;
    const rc = raw.SDL_PollEvent(&e);
    if (rc <= 0) return null;
    return e;
}
pub fn waitEvent() callconv(.Inline) !Event {
    var e: Event = undefined;
    const rc = raw.SDL_WaitEvent(&e);
    if (rc <= 0) return error.SDL_ERROR;
    return e;
}
pub fn waitEventTimeout(timeout: i32) callconv(.Inline) ?Event {
    var e: Event = undefined;
    const rc = raw.SDL_WaitEventTimeout(&e, timeout);
    if (rc <= 0) return null;
    return e;
}
pub fn pushEvent(e: Event) callconv(.Inline) !bool {
    const rc = raw.SDL_PushEvent(e);
    if (rc < 0) return error.SDL_ERROR;
    return rc != 0;
}

pub const AssertState = enum(u32) {
    retry,
    @"break",
    abort,
    ignore,
    always_ignore,
    _,
};
pub const AssertData = extern struct {
    always_ignore: IntBool,
    trigger_count: c_uint,
    condition: ?[*:0]const u8,
    filename: ?[*:0]const u8,
    linenum: c_int,
    function: ?[*:0]const u8,
    next: ?*const AssertData,
};
pub const AssertionHandler = fn(data: ?*AssertData, userdata: ?*anyopaque) AssertState;

pub const GameController = opaque{
    pub const Type = enum(u32) {
        unknown,
        xbox360,
        xboxone,
        ps3,
        ps4,
        nintendo_switch_pro,
        virtual,
        ps5,
        _,
    };

    pub const BindType = enum(u32) {
        none,
        button,
        axis,
        hat,
        _,
    };

    pub const ButtonBind = extern struct {
        bind_type: BindType,
        value: extern union {
            button: i32,
            axis: i32,
            hat: struct {
                hat: i32,
                hat_mask: i32,
            },
        },
    };

    pub const Axis = enum(i32) {
        invalid = -1,
        leftx,
        lefty,
        rightx,
        righty,
        triggerleft,
        triggerright,
        _,
        
        pub const max = @enumToInt(@This().triggerright) + 1;
    };

    pub const Button = enum(i32) {
        invalid = -1,
        a, b, x, y,
        back,
        guide,
        start,
        leftstick,
        rightstick,
        leftshoulder,
        rightshoulder,
        dpad_up,
        dpad_down,
        dpad_left,
        dpad_right,
        misc1,
        paddle1,
        paddle2,
        paddle3,
        paddle4,
        touchpad,
        _,

        pub const max = @enumToInt(@This().touchpad) + 1;
    };
};

pub const Haptic = opaque{
    pub const EffectID = enum (i32) { invalid = -1, _ };

    pub const infinity = ~@as(u32, 0);

    pub const TypeFlags = packed struct {
        constant: bool = false,
        sine: bool = false,
        leftright: bool = false,
        triangle: bool = false,
        sawtoothup: bool = false,
        sawtoothdown: bool = false,
        ramp: bool = false,
        spring: bool = false,
        
        damper: bool = false,
        inertia: bool = false,
        friction: bool = false,
        custom: bool = false,
        gain: bool = false,
        autocenter: bool = false,
        status: bool = false,
        pause: bool = false,

        pub const Enum = Type;
        pub const Int = u16;

        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn toEnum(self: @This()) Enum {
            assert(@popCount(u16, @bitCast(Int, self)) == 1);
            return @bitCast(Enum, self);
        }
        pub fn toNonstandardEnum(self: @This()) Enum {
            return @bitCast(Enum, self);
        }
    };
    pub const Type = enum (u16) {
        constant = 1<<0,
        sine = 1<<1,
        leftright = 1<<2,
        triangle = 1<<3,
        sawtoothup = 1<<4,
        sawtoothdown = 1<<5,
        ramp = 1<<6,
        spring = 1<<7,

        damper = 1<<8,
        inertia = 1<<9,
        friction = 1<<10,
        custom = 1<<11,
        gain = 1<<12,
        autocenter = 1<<13,
        status = 1<<14,
        pause = 1<<15,
        _,

        pub const Flags = TypeFlags;
        pub const Int = u16;

        pub fn toFlag(self: @This()) Flags {
            assert(@popCount(u16, @enumToInt(self)) == 1);
            return @bitCast(Flags, self);
        }
        pub fn toFlags(self: @This()) Flags {
            return @bitCast(Flags, self);
        }
        pub fn isSingleFlag(self: @This()) bool {
            return @popCount(u16, @enumToInt(self)) == 1;
        }
    };

    pub const DirectionEncoding = enum(u8) {
        polar,
        cartesian,
        spherical,
        steering_axis,
        _,
    };

    pub const Direction = extern struct {
        type: DirectionEncoding,
        dir: [3]i32,
    };

    pub const Effect = extern union {
        type: Type,
        constant: Constant,
        periodic: Periodic,
        condition: Condition,
        ramp: Ramp,
        leftright: LeftRight,
        custom: Custom,

        pub const Constant = extern struct {
            type: Type = .constant,
            direction: Direction,
            length: u32,
            delay: u16,
            button: u16,
            interval: u16,
            level: i16,
            attack_length: u16,
            attack_level: u16,
            fade_length: u16,
            fade_level: u16,
        };

        pub const Periodic = extern struct {
            type: Type,
            direction: Direction,
            length: u32,
            delay: u16,
            button: u16,
            interval: u16,
            period: u16,
            magnitude: u16,
            offset: u16,
            phase: u16,
            attack_length: u16,
            attack_level: u16,
            fade_length: u16,
            fade_level: u16,
        };

        pub const Condition = extern struct {
            type: Type,
            direction: Direction,
            length: u32,
            delay: u16,
            button: u16,
            interval: u16,
            right_sat: [3]u16,
            left_sat: [3]u16,
            right_coeff: [3]i16,
            left_coeff: [3]i16,
            deadband: [3]u16,
            center: [3]i16,
        };

        pub const Ramp = extern struct {
            type: Type = .ramp,
            direction: Direction,
            length: u32,
            delay: u16,
            button: u16,
            interval: u16,
            start: i16,
            end: i16,
            attack_length: u16,
            attack_level: u16,
            fade_length: u16,
            fade_level: u16,
        };

        pub const LeftRight = extern struct {
            type: Type = .leftright,
            length: u32,
            large_magnitude: u16,
            small_magnitude: u16,
        };

        pub const Custom = extern struct {
            type: Type = .custom,
            direction: Direction,
            length: u32,
            delay: u16,
            button: u16,
            interval: u16,
            channels: u8,
            period: u16,
            samples: u16,
            data: [*]const u16,
            attack_length: u16,
            attack_level: u16,
            fade_length: u16,
            fade_level: u16,
        };
    };

};

pub const Sensor = opaque{
    pub const ID = enum (i32) { invalid = -1, _ };

    pub const Type = enum(i32) {
        invalid = -1,
        unknown,
        accel,
        gyro,
        _,
    };

    pub const STANDARD_GRAVITY = 9.80665;
};

pub const SharedObject = opaque {};

pub const Locale = extern struct {
    language: ?[*:0]const u8,
    country: ?[*:0]const u8,
};

pub const log = struct {
    pub const max_message_len = 4096;

    pub const category = struct {
        pub const application = 0;
        pub const @"error" = 1;
        pub const assert = 2;
        pub const system = 3;
        pub const audio = 4;
        pub const video = 5;
        pub const render = 6;
        pub const input = 7;
        pub const @"test" = 8;

        // 9-18 are reserved for future use by SDL

        pub const custom = 19;
    };

    pub const Priority = enum(u32) {
        verbose = 1,
        debug = 2,
        info = 3,
        warn = 4,
        @"error" = 5,
        critical = 6,
        _,

        pub const num = @enumToInt(@This().critical) + 1;
    };

    pub const OutputFunction = fn(
        userdata: ?*anyopaque,
        category: i32,
        priority: Priority,
        message: [*:0]const u8,
    ) callconv(CC) void;
};

pub const messagebox = struct {
    pub const Flags = packed struct {
        __pad0: u4 = 0,
        @"error": bool = false,
        warning: bool = false,
        information: bool = false,
        buttons_left_to_right: bool = false,

        buttons_right_to_left: bool = false,
        __pad1: u7 = 0,

        __pad2: u8 = 0,
        __pad3: u8 = 0,

        pub const Int = u32;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
    };

    pub const ButtonFlags = packed struct {
        returnkey_default: bool = false,
        escapekey_default: bool = false,
        __pad0: u30 = 0,
    };

    pub const ButtonData = extern struct {
        flags: ButtonFlags align(4) = .{},
        buttonid: i32,
        text: [*:0]const u8,
    };

    pub const Color = extern struct { r: u8, g: u8, b: u8 };

    pub const ColorType = enum(u32) {
        background,
        text,
        button_border,
        button_background,
        button_selected,
        _,

        pub const max = @enumToInt(@This().button_selected) + 1;
    };

    pub const ColorScheme = extern struct {
        colors: [ColorType.max]messagebox.Color,
    };

    pub const Data = extern struct {
        flags: Flags align(4) = .{},
        window: ?*Window = null,
        title: [*:0]const u8,
        message: [*:0]const u8,
        numbuttons: i32,
        buttons: ?[*]ButtonData,
        colorScheme: ?*ColorScheme = null,
    };
};

pub const mouse = struct {
    pub const SystemCursor = enum(u32) {
        arrow,
        ibeam,
        wait,
        crosshair,
        waitarrow,
        sizenwse,
        sizenesw,
        sizewe,
        sizens,
        sizeall,
        no,
        hand,
        _,

        pub const num = @enumToInt(@This().hand) + 1;
    };
    pub const Cursor = opaque{};
    pub const WheelDirection = enum(u32) {
        normal,
        flipped,
        _,
    };
    pub const Buttons = packed struct {
        left: bool = false,
        middle: bool = false,
        right: bool = false,
        x1: bool = false,
        x2: bool = false,
        button_6: bool = false,
        button_7: bool = false,
        button_8: bool = false,
        button_9: bool = false,
        button_10: bool = false,
        button_11: bool = false,
        button_12: bool = false,
        button_13: bool = false,
        button_14: bool = false,
        button_15: bool = false,
        button_16: bool = false,
        button_17: bool = false,
        button_18: bool = false,
        button_19: bool = false,
        button_20: bool = false,
        button_21: bool = false,
        button_22: bool = false,
        button_23: bool = false,
        button_24: bool = false,
        button_25: bool = false,
        button_26: bool = false,
        button_27: bool = false,
        button_28: bool = false,
        button_29: bool = false,
        button_30: bool = false,
        button_31: bool = false,

        pub const Int = u32;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
        pub fn anyPressed(self: Buttons) bool {
            return self.toInt() != 0;
        }
        pub fn isPressed(self: Buttons, button: u5) bool {
            return (self.toInt() & (@as(Int, 1) << button)) != 0;
        }
    };
};

pub const power = struct {
    pub const State = enum(u32) {
        unknown,
        on_battery,
        no_battery,
        charging,
        charged,
        _,

        pub const @"error" = @intToEnum(@This(), -1);
    };
};

pub const Renderer = opaque{
    pub const Flags = packed struct {
        software: bool = false,
        accelerated: bool = false,
        presentvsync: bool = false,
        targettexture: bool = false,
        __pad0: u28 = 0,

        pub const Int = u32;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
    };

    pub const Info = extern struct {
        name: [*:0]const u8,
        flags: Flags align(4),
        num_texture_formats: u32,
        texture_formats: [16]Format,
        max_texture_width: i32,
        max_texture_height: i32,
    };

    pub const Flip = packed struct {
        horizontal: bool = false,
        vertical: bool = false,
        __pad0: u30 = 0,

        pub const Int = u32;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
    };
};

pub const Texture = opaque{
    pub const ScaleMode = enum(u32) {
        nearest,
        linear,
        best,
        _,
    };

    pub const Access = enum(u32) {
        static,
        streaming,
        target,
        _,
    };

    pub const Modulate = packed struct {
        color: bool = false,
        alpha: bool = false,
        __pad0: u30 = 0,

        pub const Int = u32;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
    };
};

pub const Surface = extern struct {
    flags: Flags align(4), // read only
    format: ?*const PixelFormat, // read only
    w: i32, // read only
    h: i32, // read only
    pitch: i32, // read only
    pixels: ?*anyopaque, // read/write

    userdata: ?*anyopaque, // read/write
    locked: i32, // read only
    _list_blitmap: ?*anyopaque, // private
    clip_rect: Rect, // read only
    _map: ?*anyopaque, // private
    refcount: i32, // read-mostly

    pub const Flags = packed struct {
        prealloc: bool = false,
        rleaccel: bool = false,
        dontfree: bool = false,
        simd_aligned: bool = false,
        __pad0: u28 = 0,

        pub const Int = u32;
        pub fn toInt(self: @This()) Int {
            return @bitCast(Int, self);
        }
        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
    };

    pub const Blit = fn(src: *Surface, src_rect: *Rect, dst: Surface, dst_rect: *Rect) callconv(CC) c_int;
};

pub const YuvConversionMode = enum(u32) {
    jpeg,
    bt601,
    bt709,
    automatic,
    _,
};

pub const InitFlags = packed struct {
    timer: bool = false,
    __pad0: u3 = 0,
    audio: bool = false,
    video: bool = false, // implies events
    __pad1: u2 = 0,

    __pad2: u1 = 0,
    joystick: bool = false, // implies events
    __pad3: u2 = 0,
    haptic: bool = false,
    gamecontroller: bool = false, // implies joystick
    events: bool = false,
    sensor: bool = false,

    __pad4: u4 = 0,
    noparachute: bool = false, // backwards compat, ignored
    __pad5: u3 = 0,

    __pad6: u8 = 0,

    pub const everything: InitFlags = .{
        .timer = true,
        .audio = true,
        .video = true,
        .events = true,
        .joystick = true,
        .haptic = true,
        .gamecontroller = true,
        .sensor = true,
    };

    pub const Int = u32;
    pub fn fromInt(int: Int) @This() {
        return @bitCast(@This(), int);
    }
    pub fn toInt(self: @This()) Int {
        return @bitCast(Int, self);
    }

    comptime {
        if (@sizeOf(InitFlags) != @sizeOf(Int))
            @compileError("InitFlags must be 4 bytes long");
        if (@bitSizeOf(InitFlags) != @bitSizeOf(Int))
            @compileError("InitFlags must be 32 bits long");
    }
};

pub fn Init(flags: InitFlags) !void {
    const rc = raw.SDL_Init(flags.toInt());
    if (rc < 0) return error.SDL_ERROR;
}
pub const Quit = raw.SDL_Quit;

pub const raw = struct {
    // --------------------------- SDL.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_Init(flags: InitFlags.Int) callconv(CC) c_int;
    pub extern fn SDL_InitSubSystem(flags: InitFlags.Int) callconv(CC) c_int;
    pub extern fn SDL_QuitSubSystem(flags: InitFlags.Int) callconv(CC) void;
    pub extern fn SDL_WasInit(flags: InitFlags.Int) callconv(CC) InitFlags.Int;
    pub extern fn SDL_Quit() callconv(CC) void;

    // --------------------------- SDL_assert.h --------------------------
    // [ ] Wrappers
    pub fn SDL_TriggerBreakpoint() callconv(.Inline) void {
        @breakpoint();
    }
    pub extern fn SDL_SetAssertionHandler(handler: ?AssertionHandler, userdata: ?*anyopaque) callconv(CC) void;
    pub extern fn SDL_GetDefaultAssertionHandler() callconv(CC) AssertionHandler;
    pub extern fn SDL_GetAssertionHandler(puserdata: ?*?*anyopaque) callconv(CC) AssertionHandler;
    pub extern fn SDL_GetAssertionReport() callconv(CC) ?*const AssertData;
    pub extern fn SDL_ResetAssertionReport() callconv(CC) void;

    // --------------------------- SDL_audio.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetNumAudioDrivers() callconv(CC) i32;
    pub extern fn SDL_GetAudioDriver(index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_AudioInit(driver_name: ?[*:0]const u8) callconv(CC) i32;
    pub extern fn SDL_AudioQuit() callconv(CC) void;
    pub extern fn SDL_GetCurrentAudioDriver() callconv(CC) ?[*:0]const u8;

    pub extern fn SDL_OpenAudio(desired: *audio.Spec, obtained: ?*audio.Spec) callconv(CC) i32;
    pub extern fn SDL_GetNumAudioDevices(iscapture: i32) callconv(CC) i32;
    pub extern fn SDL_GetAudioDeviceName(index: i32, iscapture: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_OpenAudioDevice(
        device: ?[*:0]const u8,
        iscapture: i32,
        desired: *const audio.Spec,
        obtained: ?*const audio.Spec,
        allowed_changes: i32,
    ) callconv(CC) audio.DeviceID;
    pub extern fn SDL_GetAudioDeviceStatus(device: audio.DeviceID) callconv(CC) audio.Status;
    pub extern fn SDL_PauseAudio(pause_on: i32) callconv(CC) void;
    pub extern fn SDL_PauseAudioDevice(device: audio.DeviceID, pause_on: i32) callconv(CC) void;

    pub extern fn SDL_LoadWAV_RW(src: *RWops, freesrc: i32, spec: *audio.Spec, audio_buf: *?[*]u8, audio_len: *u32) callconv(CC) ?*audio.Spec;
    pub fn SDL_LoadWAV(file: ?[*:0]const u8, spec: *audio.Spec, audio_buf: *?[*]u8, audio_len: *u32) callconv(.Inline) ?*audio.Spec {
        const rw = SDL_RWFromFile(file, "rb") orelse return null;
        return SDL_LoadWAV_RW(rw, 1, spec, audio_buf, audio_len);
    }
    pub extern fn SDL_FreeWAV(audio_buf: ?[*]u8) callconv(CC) void;

    pub extern fn SDL_BuildAudioCVT(
        cvt: *audio.CVT,
        src_format: audio.Format.Int,
        src_channels: u8,
        src_rate: i32,
        dst_format: audio.Format.Int,
        dst_channels: u8,
        dst_rate: i32,
    ) callconv(CC) i32;
    pub extern fn SDL_ConvertAudio(cvt: *audio.CVT) callconv(CC) i32;

    pub extern fn SDL_NewAudioStream(
        src_format: audio.Format.Int,
        src_channels: u8,
        src_rate: i32,
        dst_format: audio.Format.Int,
        dst_channels: u8,
        dst_rate: i32,
    ) callconv(CC) ?*audio.Stream;
    pub extern fn SDL_AudioStreamPut(stream: *audio.Stream, buf: ?*anyopaque, len: i32) callconv(CC) i32;
    pub extern fn SDL_AudioStreamGet(stream: *audio.Stream, buf: ?*anyopaque, len: i32) callconv(CC) i32;
    pub extern fn SDL_AudioStreamAvailable(stream: *audio.Stream) callconv(CC) i32;
    pub extern fn SDL_AudioStreamFlush(stream: *audio.Stream) callconv(CC) i32;
    pub extern fn SDL_AudioStreamClear(stream: *audio.Stream) callconv(CC) void;
    pub extern fn SDL_FreeAudioStream(stream: *audio.Stream) callconv(CC) void;

    pub extern fn SDL_MixAudio(dst: [*]u8, src: [*]const u8, len: u32, volume: c_int) callconv(CC) void;
    pub extern fn SDL_MixAudioFormat(dst: [*]u8, src: [*]const u8, format: audio.Format.Int, len: u32, volume: c_int) callconv(CC) void;

    pub extern fn SDL_QueueAudio(device: audio.DeviceID, data: ?*anyopaque, len: u32) callconv(CC) c_int;
    pub extern fn SDL_DequeueAudio(device: audio.DeviceID, data: ?*anyopaque, len: u32) callconv(CC) c_int;
    pub extern fn SDL_GetQueuedAudioSize(dev: audio.DeviceID) callconv(CC) u32;
    pub extern fn SDL_ClearQueuedAudio(dev: audio.DeviceID) callconv(CC) void;
    pub extern fn SDL_LockAudio() callconv(CC) void;
    pub extern fn SDL_LockAudioDevice(dev: audio.DeviceID) callconv(CC) void;
    pub extern fn SDL_UnlockAudio() callconv(CC) void;
    pub extern fn SDL_UnlockAudioDevice(dev: audio.DeviceID) callconv(CC) void;
    pub extern fn SDL_CloseAudio() callconv(CC) void;
    pub extern fn SDL_CloseAudioDevice(dev: audio.DeviceID) callconv(CC) void;

    // --------------------------- SDL_blendmode.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_ComposeCustomBlendMode(
        src_color_factor: BlendFactor,
        dst_color_factor: BlendFactor,
        color_operation: BlendOperation,
        src_alpha_factor: BlendFactor,
        dst_alpha_factor: BlendFactor,
        alpha_operation: BlendOperation,
    ) callconv(CC) BlendMode;

    // --------------------------- SDL_clipboard.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_SetClipboardText(text: [*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_GetClipboardText() callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_HasClipboardText() callconv(CC) IntBool;

    // --------------------------- SDL_cpuinfo.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetCPUCount() callconv(CC) i32;
    pub extern fn SDL_GetCPUCacheLineSize() callconv(CC) i32;
    pub extern fn SDL_HasRDTSC() callconv(CC) IntBool;
    pub extern fn SDL_HasAltiVec() callconv(CC) IntBool;
    pub extern fn SDL_HasMMX() callconv(CC) IntBool;
    pub extern fn SDL_Has3DNow() callconv(CC) IntBool;
    pub extern fn SDL_HasSSE() callconv(CC) IntBool;
    pub extern fn SDL_HasSSE2() callconv(CC) IntBool;
    pub extern fn SDL_HasSSE3() callconv(CC) IntBool;
    pub extern fn SDL_HasSSE41() callconv(CC) IntBool;
    pub extern fn SDL_HasAVX() callconv(CC) IntBool;
    pub extern fn SDL_HasAVX2() callconv(CC) IntBool;
    pub extern fn SDL_HasAVX512F() callconv(CC) IntBool;
    pub extern fn SDL_HasARMSIMD() callconv(CC) IntBool;
    pub extern fn SDL_HasNEON() callconv(CC) IntBool;
    pub extern fn SDL_GetSystemRAM() callconv(CC) i32;
    pub extern fn SDL_SIMDGetAlignment() callconv(CC) usize;
    pub extern fn SDL_SIMDAlloc(len: usize) callconv(CC) ?*anyopaque;
    pub extern fn SDL_SIMDRealloc(mem: ?*anyopaque, len: usize) callconv(CC) ?*anyopaque;
    pub extern fn SDL_SIMDFree(ptr: ?*anyopaque) callconv(CC) void;

    // --------------------------- SDL_error.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_SetError(fmt: [*:0]const u8, ...) callconv(CC) c_int;
    pub extern fn SDL_GetError() callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetErrorMsg(errstr: [*]u8, maxlen: u32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_ClearError() callconv(CC) void;

    // --------------------------- SDL_events.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_PumpEvents() callconv(CC) void;
    pub extern fn SDL_PeepEvents(events: ?[*]Event, numevents: i32, action: Event.Action, minType: Event.Type, maxType: Event.Type) callconv(CC) i32;
    pub extern fn SDL_HasEvent(@"type": Event.Type) callconv(CC) IntBool;
    pub extern fn SDL_HasEvents(minType: Event.Type, maxType: Event.Type) callconv(CC) IntBool;
    pub extern fn SDL_FlushEvent(@"type": Event.Type) callconv(CC) void;
    pub extern fn SDL_FlushEvents(minType: Event.Type, maxType: Event.Type) callconv(CC) void;
    pub extern fn SDL_PollEvent(event: *Event) callconv(CC) IntBool;
    pub extern fn SDL_WaitEvent(event: *Event) callconv(CC) IntBool;
    pub extern fn SDL_WaitEventTimeout(event: *Event, timeout: i32) callconv(CC) IntBool;
    pub extern fn SDL_PushEvent(event: *Event) callconv(CC) IntBool;

    pub extern fn SDL_SetEventFilter(filter: ?Event.Filter, userdata: ?*anyopaque) callconv(CC) void;
    pub extern fn SDL_GetEventFilter(filter: *?Event.Filter, userdata: *?*anyopaque) callconv(CC) IntBool;
    pub extern fn SDL_AddEventWatch(filter: Event.Filter, userdata: ?*anyopaque) callconv(CC) void;
    pub extern fn SDL_DelEventWatch(filter: Event.Filter, userdata: ?*anyopaque) callconv(CC) void;
    pub extern fn SDL_FilterEvents(filter: Event.Filter, userdata: ?*anyopaque) callconv(CC) void;

    pub extern fn SDL_EventState(@"type": Event.Type, state: Event.State) callconv(CC) u8;
    pub fn SDL_GetEventState(@"type": Event.Type) callconv(.Inline) Event.State {
        return @intToEnum(Event.State, @intCast(c_int, SDL_EventState(@"type", .query)));
    }
    pub extern fn SDL_RegisterEvents(numevents: i32) callconv(CC) u32;

    // --------------------------- SDL_filesystem.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetBasePath() callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetPrefPath(org: [*:0]const u8, app: [*:0]const u8) callconv(CC) ?[*:0]const u8;

    // --------------------------- SDL_gamecontroller.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GameControllerAddMappingsFromRW(rw: *RWops, freerw: IntBool) callconv(CC) c_int;
    pub fn SDL_GameControllerAddMappingsFromFile(file: [*:0]const u8) callconv(.Inline) c_int {
        const rw = SDL_RWFromFile(file, "rb") orelse return -1;
        return SDL_GameControllerAddMappingsFromRW(rw, 1);
    }
    pub extern fn SDL_GameControllerAddMapping(mapping_string: [*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_GameControllerNumMappings() callconv(CC) i32;
    pub extern fn SDL_GameControllerMappingForIndex(mapping_index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GameControllerMappingForGUID(guid: Joystick.GUID) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GameControllerMapping(gamecontroller: *GameController) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_IsGameController(joystick_index: i32) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerNameForIndex(joystick_index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GameControllerTypeForIndex(joystick_index: i32) callconv(CC) GameController.Type;
    pub extern fn SDL_GameControllerMappingForDeviceIndex(joystick_index: i32) callconv(CC) ?[*:0]const u8;

    pub extern fn SDL_GameControllerOpen(joystick_index: i32) callconv(CC) ?*GameController;
    pub extern fn SDL_GameControllerFromInstanceID(joyid: Joystick.ID) callconv(CC) ?*GameController;
    pub extern fn SDL_GameControllerFromPlayerIndex(player_index: i32) callconv(CC) ?*GameController;
    pub extern fn SDL_GameControllerName(c: *GameController) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GameControllerGetType(c: *GameController) callconv(CC) GameController.Type;
    pub extern fn SDL_GameControllerGetPlayerIndex(c: *GameController) callconv(CC) i32;
    pub extern fn SDL_GameControllerSetPlayerIndex(c: *GameController, player_index: i32) callconv(CC) void;
    pub extern fn SDL_GameControllerGetVendor(c: *GameController) callconv(CC) u16;
    pub extern fn SDL_GameControllerGetProduct(c: *GameController) callconv(CC) u16;
    pub extern fn SDL_GameControllerGetProductVersion(c: *GameController) callconv(CC) u16;
    pub extern fn SDL_GameControllerGetSerial(c: *GameController) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GameControllerGetAttached(c: *GameController) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerGetJoystick(c: *GameController) callconv(CC) ?*Joystick;

    pub extern fn SDL_GameControllerEventState(state: Event.State) callconv(CC) Event.State;
    pub extern fn SDL_GameControllerUpdate() callconv(CC) void;

    pub extern fn SDL_GameControllerGetAxisFromString(pch_string: [*:0]const u8) callconv(CC) GameController.Axis;
    pub extern fn SDL_GameControllerGetStringForAxis(axis: GameController.Axis) callconv(CC) ?[*:0]const u8;
    // ABI Problem: return struct by value
    pub extern fn SDL_GameControllerGetBindForAxis(c: *GameController, axis: GameController.Axis) callconv(CC) GameController.ButtonBind;
    pub extern fn SDL_GameControllerHasAxis(c: *GameController, axis: GameController.Axis) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerGetAxis(c: *GameController, axis: GameController.Axis) callconv(CC) i16;

    pub extern fn SDL_GameControllerGetButtonFromString(pch_string: [*:0]const u8) callconv(CC) GameController.Button;
    pub extern fn SDL_GameControllerGetStringForButton(button: GameController.Button) callconv(CC) ?[*:0]const u8;
    // ABI Problem: return struct by value
    pub extern fn SDL_GameControllerGetBindForButton(c: *GameController, button: GameController.Button) callconv(CC) GameController.ButtonBind;
    pub extern fn SDL_GameControllerHasButton(c: *GameController, button: GameController.Button) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerGetButton(c: *GameController, button: GameController.Button) callconv(CC) u8;

    pub extern fn SDL_GameControllerGetNumTouchpads(c: *GameController) callconv(CC) i32;
    pub extern fn SDL_GameControllerGetNumTouchpadFingers(c: *GameController, touchpad: i32) callconv(CC) i32;
    pub extern fn SDL_GameControllerGetTouchpadFinger(
        c: *GameController,
        touchpad: i32,
        finger: i32,
        state: *u8,
        x: *f32,
        y: *f32,
        pressure: *f32,
    ) callconv(CC) c_int;

    pub extern fn SDL_GameControllerHasSensor(c: *GameController, sensor: Sensor.Type) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerSetSensorEnabled(c: *GameController, sensor: Sensor.Type, enabled: IntBool) callconv(CC) c_int;
    pub extern fn SDL_GameControllerIsSensorEnabled(c: *GameController, sensor: Sensor.Type) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerGetSensorData(c: *GameController, sensor: Sensor.Type, data: [*]f32, num_values: i32) callconv(CC) c_int;

    pub extern fn SDL_GameControllerRumble(c: *GameController, low_freq_rumble: u16, high_freq_rumble: u16, duration_ms: u32) callconv(CC) c_int;
    pub extern fn SDL_GameControllerRumbleTriggers(c: *GameController, left_rumble: u16, right_rumble: u16, duration_ms: u32) callconv(CC) c_int;

    pub extern fn SDL_GameControllerHasLED(c: *GameController) callconv(CC) IntBool;
    pub extern fn SDL_GameControllerSetLED(c: *GameController, red: u8, green: u8, blue: u8) callconv(CC) c_int;
    pub extern fn SDL_GameControllerClose(c: *GameController) callconv(CC) void;

    // --------------------------- SDL_gesture.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_RecordGesture(touchId: TouchID) callconv(CC) i32;
    pub extern fn SDL_SaveAllDollarTemplates(dst: *RWops) callconv(CC) i32;
    pub extern fn SDL_SaveDollarTemplate(gestureId: GestureID, dst: *RWops) callconv(CC) i32;
    pub extern fn SDL_LoadDollarTemplates(touchId: TouchID, src: *RWops) callconv(CC) i32;

    // --------------------------- SDL_haptic.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_NumHaptics() callconv(CC) i32;
    pub extern fn SDL_HapticName(device_index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_HapticOpen(device_index: i32) callconv(CC) ?*Haptic;
    pub extern fn SDL_HapticOpened(device_index: i32) callconv(CC) IntBool;
    pub extern fn SDL_HapticIndex(haptic: *Haptic) callconv(CC) i32;
    pub extern fn SDL_MouseIsHaptic() callconv(CC) IntBool;
    pub extern fn SDL_HapticOpenFromMouse() callconv(CC) ?*Haptic;
    pub extern fn SDL_JoystickIsHaptic(joystick: *Joystick) callconv(CC) IntBool;
    pub extern fn SDL_HapticOpenFromJoystick(joystick: *Joystick) callconv(CC) ?*Haptic;
    pub extern fn SDL_HapticClose(haptic: *Haptic) callconv(CC) void;
    pub extern fn SDL_HapticNumEffects(haptic: *Haptic) callconv(CC) i32;
    pub extern fn SDL_HapticNumEffectsPlaying(haptic: *Haptic) callconv(CC) i32;
    pub extern fn SDL_HapticQuery(haptic: *Haptic) callconv(CC) Haptic.TypeFlags.Int;
    pub extern fn SDL_HapticNumAxes(haptic: *Haptic) callconv(CC) i32;
    pub extern fn SDL_HapticEffectSupported(haptic: *Haptic, effect: *const Haptic.Effect) callconv(CC) c_int;
    pub extern fn SDL_HapticNewEffect(haptic: *Haptic, effect: *const Haptic.Effect) callconv(CC) Haptic.EffectID;
    pub extern fn SDL_HapticUpdateEffect(haptic: *Haptic, effect: Haptic.EffectID, data: *const Haptic.Effect) callconv(CC) c_int;
    pub extern fn SDL_HapticRunEffect(haptic: *Haptic, effect: Haptic.EffectID, iterations: u32) callconv(CC) c_int;
    pub extern fn SDL_HapticStopEffect(haptic: *Haptic, effect: Haptic.EffectID) callconv(CC) c_int;
    pub extern fn SDL_HapticDestroyEffect(haptic: *Haptic, effect: Haptic.EffectID) callconv(CC) void;
    pub extern fn SDL_HapticGetEffectStatus(haptic: *Haptic, effect: Haptic.EffectID) callconv(CC) c_int;
    pub extern fn SDL_HapticSetGain(haptic: *Haptic, gain: i32) callconv(CC) c_int;
    pub extern fn SDL_HapticSetAutocenter(haptic: *Haptic, autocenter: i32) callconv(CC) c_int;
    pub extern fn SDL_HapticPause(haptic: *Haptic) callconv(CC) c_int;
    pub extern fn SDL_HapticUnpause(haptic: *Haptic) callconv(CC) c_int;
    pub extern fn SDL_HapticStopAll(haptic: *Haptic) callconv(CC) c_int;
    pub extern fn SDL_HapticRumbleSupported(haptic: *Haptic) callconv(CC) c_int;
    pub extern fn SDL_HapticRumbleInit(haptic: *Haptic) callconv(CC) c_int;
    pub extern fn SDL_HapticRumblePlay(haptic: *Haptic, strength: f32, length: u32) callconv(CC) c_int;
    pub extern fn SDL_HapticRumbleStop(haptic: *Haptic) callconv(CC) c_int;

    // --------------------------- SDL_joystick.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_LockJoysticks() callconv(CC) void;
    pub extern fn SDL_UnlockJoysticks() callconv(CC) void;
    pub extern fn SDL_NumJoysticks() callconv(CC) i32;
    pub extern fn SDL_JoystickNameForIndex(device_index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_JoystickGetDevicePlayerIndex(device_index: i32) callconv(CC) i32;
    /// Note: On some platforms this may not be correctly handled at the ABI layer.
    /// TODO: Wrap this with a C stub.
    pub extern fn SDL_JoystickGetDeviceGUID(device_index: i32) callconv(CC) Joystick.GUID;
    pub extern fn SDL_JoystickGetDeviceVendor(device_index: i32) callconv(CC) u16;
    pub extern fn SDL_JoystickGetDeviceProduct(device_index: i32) callconv(CC) u16;
    pub extern fn SDL_JoystickGetDeviceType(device_index: i32) callconv(CC) Joystick.Type;
    pub extern fn SDL_JoystickGetDeviceInstanceID(device_index: i32) callconv(CC) Joystick.ID;
    pub extern fn SDL_JoystickOpen(device_index: i32) callconv(CC) ?*Joystick;
    pub extern fn SDL_JoystickFromInstanceID(instance_id: Joystick.ID) callconv(CC) ?*Joystick;
    pub extern fn SDL_JoystickFromPlayerIndex(player_index: i32) callconv(CC) ?*Joystick;
    pub extern fn SDL_JoystickAttachVirtual(@"type": Joystick.Type, naxes: i32, nbuttons: i32, nhats: i32) callconv(CC) i32;
    pub extern fn SDL_JoystickDetachVirtual(device_index: i32) callconv(CC) i32;
    pub extern fn SDL_JoystickIsVirtual(device_index: i32) callconv(CC) IntBool;
    pub extern fn SDL_JoystickSetVirtualAxis(joystick: *Joystick, axis: i32, value: i16) callconv(CC) i32;
    pub extern fn SDL_JoystickSetVirtualButton(joystick: *Joystick, button: i32, value: u8) callconv(CC) i32;
    pub extern fn SDL_JoystickSetVirtualHat(joystick: *Joystick, hat: i32, value: Joystick.Hat) callconv(CC) i32;
    pub extern fn SDL_JoystickName(joystick: *Joystick) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_JoystickGetPlayerIndex(joystick: *Joystick) callconv(CC) i32;
    pub extern fn SDL_JoystickSetPlayerIndex(joystick: *Joystick, player_index: i32) callconv(CC) void;
    pub extern fn SDL_JoystickGetGUID(joystick: *Joystick) callconv(CC) Joystick.GUID;
    pub extern fn SDL_JoystickGetVendor(joystick: *Joystick) callconv(CC) u16;
    pub extern fn SDL_JoystickGetProduct(joystick: *Joystick) callconv(CC) u16;
    pub extern fn SDL_JoystickGetProductVersion(joystick: *Joystick) callconv(CC) u16;
    pub extern fn SDL_JoystickGetSerial(joystick: *Joystick) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_JoystickGetType(joystick: *Joystick) callconv(CC) Joystick.Type;
    pub extern fn SDL_JoystickGetGUIDString(guid: Joystick.GUID, pszGUID: *[33]u8, cbGUID: i32) callconv(CC) void;
    pub extern fn SDL_JoystickGetGUIDFromString(pchGUID: [*:0]const u8) callconv(CC) Joystick.GUID;
    pub extern fn SDL_JoystickGetAttached(joystick: *Joystick) callconv(CC) IntBool;
    pub extern fn SDL_JoystickInstanceID(joystick: *Joystick) callconv(CC) Joystick.ID;
    pub extern fn SDL_JoystickNumAxes(joystick: *Joystick) callconv(CC) i32;
    pub extern fn SDL_JoystickNumBalls(joystick: *Joystick) callconv(CC) i32;
    pub extern fn SDL_JoystickNumHats(joystick: *Joystick) callconv(CC) i32;
    pub extern fn SDL_JoystickNumButtons(joystick: *Joystick) callconv(CC) i32;
    pub extern fn SDL_JoystickUpdate() callconv(CC) void;
    pub extern fn SDL_JoystickEventState(state: Event.State) callconv(CC) i32;
    pub extern fn SDL_JoystickGetAxis(joystick: *Joystick, axis: i32) callconv(CC) i16;
    pub extern fn SDL_JoystickGetAxisInitialState(joystick: *Joystick, axis: i32, state: *i16) callconv(CC) IntBool;
    pub extern fn SDL_JoystickGetHat(joystick: *Joystick, hat: i32) callconv(CC) Joystick.Hat;
    pub extern fn SDL_JoystickGetBall(joystick: *Joystick, ball: i32, dx: *i32, dy: *i32) callconv(CC) i32;
    pub extern fn SDL_JoystickGetButton(joystick: *Joystick, button: i32) callconv(CC) u8;
    pub extern fn SDL_JoystickRumble(joystick: *Joystick, low_frequency_rumble: u16, high_frequency_rumble: u16, duration_ms: u32) callconv(CC) i32;
    pub extern fn SDL_JoystickRumbleTriggers(joystick: *Joystick, left_rumble: u16, right_rumble: u16, duration_ms: u32) callconv(CC) i32;
    pub extern fn SDL_JoystickHasLED(joystick: *Joystick) callconv(CC) IntBool;
    pub extern fn SDL_JoystickSetLED(joystick: *Joystick, red: u8, green: u8, blue: u8) callconv(CC) i32;
    pub extern fn SDL_JoystickClose(joystick: *Joystick) callconv(CC) void;
    pub extern fn SDL_JoystickCurrentPowerLevel(joystick: *Joystick) callconv(CC) Joystick.PowerLevel;

    // --------------------------- SDL_keyboard.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetKeyboardFocus() callconv(CC) ?*Window;
    pub extern fn SDL_GetKeyboardState(numkeys: ?*i32) callconv(CC) ?[*]const u8;
    pub extern fn SDL_GetModState() callconv(CC) KeymodInt;
    pub extern fn SDL_SetModState(modstate: KeymodInt) callconv(CC) void;
    pub extern fn SDL_GetKeyFromScancode(scancode: Scancode) callconv(CC) Keycode;
    pub extern fn SDL_GetScancodeFromKey(key: Keycode) callconv(CC) Scancode;
    pub extern fn SDL_GetScancodeName(scancode: Scancode) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetScancodeFromName(name: ?[*:0]const u8) callconv(CC) Scancode;
    pub extern fn SDL_GetKeyName(key: Keycode) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetKeyFromName(name: ?[*:0]const u8) callconv(CC) Keycode;
    pub extern fn SDL_StartTextInput() callconv(CC) void;
    pub extern fn SDL_IsTextInputActive() callconv(CC) IntBool;
    pub extern fn SDL_StopTextInput() callconv(CC) void;
    pub extern fn SDL_SetTextInputRect(rect: *Rect) callconv(CC) void;
    pub extern fn SDL_HasScreenKeyboardSupport() callconv(CC) IntBool;
    pub extern fn SDL_IsScreenKeyboardShown(window: *Window) callconv(CC) IntBool;

    // --------------------------- SDL_loadso.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_LoadObject(sofile: [*:0]const u8) callconv(CC) ?*SharedObject;
    pub extern fn SDL_LoadFunction(handle: *SharedObject, name: [*:0]const u8) callconv(CC) ?*anyopaque;
    pub extern fn SDL_UnloadObject(handle: *SharedObject) callconv(CC) void;

    // --------------------------- SDL_locale.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetPreferredLocales() callconv(CC) ?[*]Locale;

    // --------------------------- SDL_log.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_LogSetAllPriority(priority: log.Priority) callconv(CC) void;
    pub extern fn SDL_LogSetPriority(category: i32, priority: log.Priority) callconv(CC) void;
    pub extern fn SDL_LogGetPriority(category: i32) callconv(CC) log.Priority;
    pub extern fn SDL_LogResetPriorities() callconv(CC) void;
    pub extern fn SDL_Log(fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogVerbose(category: i32, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogDebug(category: i32, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogInfo(category: i32, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogWarn(category: i32, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogError(category: i32, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogCritical(category: i32, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogMessage(category: i32, priority: log.Priority, fmt: [*:0]const u8, ...) callconv(CC) void;
    pub extern fn SDL_LogGetOutputFunction(callback: *log.OutputFunction, userdata: *?*anyopaque) callconv(CC) void;
    pub extern fn SDL_LogSetOutputFunction(callback: log.OutputFunction, userdata: ?*anyopaque) callconv(CC) void;

    // --------------------------- SDL_messagebox.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_ShowMessageBox(data: *const messagebox.Data, buttonid: *i32) callconv(CC) c_int;
    pub extern fn SDL_ShowMessageBoxSimple(flags: messagebox.Flags.Int, title: [*:0]const u8, message: [*:0]const u8, window: ?*Window) callconv(CC) c_int;

    // --------------------------- SDL_mouse.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetMouseFocus() callconv(CC) ?*Window;
    pub extern fn SDL_GetMouseState(x: ?*i32, y: ?*i32) callconv(CC) mouse.Buttons.Int;
    pub extern fn SDL_GetGlobalMouseState(x: ?*i32, y: ?*i32) callconv(CC) mouse.Buttons.Int;
    pub extern fn SDL_GetRelativeMouseState(x: ?*i32, y: ?*i32) callconv(CC) mouse.Buttons.Int;
    pub extern fn SDL_WarpMouseInWindow(window: ?*Window, x: i32, y: i32) callconv(CC) void;
    pub extern fn SDL_WarpMouseGlobal(x: i32, y: i32) callconv(CC) c_int;
    pub extern fn SDL_SetRelativeMouseMode(enabled: IntBool) callconv(CC) c_int;
    pub extern fn SDL_CatpureMouse(enabled: IntBool) callconv(CC) c_int;
    pub extern fn SDL_GetRelativeMouseMode() callconv(CC) IntBool;

    pub extern fn SDL_CreateCursor(data: [*]const u8, mask: [*]const u8, w: i32, h: i32, hot_x: i32, hot_y: i32) callconv(CC) ?*mouse.Cursor;
    pub extern fn SDL_CreateColorCursor(surface: *Surface, hot_x: i32, hot_y: i32) callconv(CC) ?*mouse.Cursor;
    pub extern fn SDL_CreateSystemCursor(id: mouse.SystemCursor) callconv(CC) ?*mouse.Cursor;
    pub extern fn SDL_SetCursor(cursor: *mouse.Cursor) callconv(CC) void;
    pub extern fn SDL_GetCursor() callconv(CC) ?*mouse.Cursor;
    pub extern fn SDL_GetDefaultCursor() callconv(CC) ?*mouse.Cursor;
    pub extern fn SDL_FreeCursor(cursor: *mouse.Cursor) callconv(CC) void;
    pub extern fn SDL_ShowCursor(toggle: Event.State) callconv(CC) Event.State;

    // --------------------------- SDL_pixels.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetPixelFormatName(format: Format) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_PixelFormatEnumToMasks(format: Format, bpp: *i32, rMask: *u32, gMask: *u32, bMask: *u32, aMask: *u32) callconv(CC) IntBool;
    pub extern fn SDL_MasksToPixelFormatEnum(bpp: i32, rMask: u32, gMask: u32, bMask: u32, aMask: u32) callconv(CC) Format.Int;
    pub extern fn SDL_AllocFormat(pixel_format: Format) callconv(CC) ?*const PixelFormat;
    pub extern fn SDL_FreeFormat(format: *const PixelFormat) callconv(CC) void;
    pub extern fn SDL_AllocPalette(ncolors: i32) callconv(CC) ?*const Palette;
    pub extern fn SDL_SetPixelFormatPalette(format: *const PixelFormat, palette: *const Palette) callconv(CC) c_int;
    pub extern fn SDL_SetPaletteColors(palette: *const Palette, colors: [*]const Color, firstcolor: i32, ncolors: i32) callconv(CC) c_int;
    pub extern fn SDL_FreePalette(palette: *const Palette) callconv(CC) void;
    pub extern fn SDL_MapRGB(format: *const PixelFormat, r: u8, g: u8, b: u8) callconv(CC) u32;
    pub extern fn SDL_MapRGBA(format: *const PixelFormat, r: u8, g: u8, b: u8, a: u8) callconv(CC) u32;
    pub extern fn SDL_GetRGB(pixel: u32, format: *const PixelFormat, r: *u8, g: *u8, b: *u8) callconv(CC) void;
    pub extern fn SDL_GetRGBA(pixel: u32, format: *const PixelFormat, r: *u8, g: *u8, b: *u8, a: *u8) callconv(CC) void;
    pub extern fn SDL_CalculateGammaRamp(gamma: f32, ramp: *[256]u16) callconv(CC) void;

    // --------------------------- SDL_pixels.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetPowerInfo(secs: ?*i32, pct: ?*i32) callconv(CC) power.State;

    // --------------------------- SDL_quit.h --------------------------
    // [ ] Wrappers
    pub fn SDL_QuitRequested() callconv(.Inline) bool {
        SDL_PumpEvents();
        return SDL_PeepEvents(null, 0, .peek, .QUIT, .QUIT) > 0;
    }

    // --------------------------- SDL_rect.h --------------------------
    // [ ] Wrappers
    pub fn SDL_PointInRect(p: *const Point, r: *const Rect) callconv(.Inline) bool {
        return ((p.x >= r.x) and (p.x < (r.x + r.w)) and
                (p.y >= r.y) and (p.y < (r.y + r.h)));
    }
    pub fn SDL_RectEmpty(r: ?*const Rect) callconv(.Inline) bool {
        return (r == null) or (r.?.w <= 0) or (r.?.h <= 0);
    }
    pub fn SDL_RectEquals(a: ?*const Rect, b: ?*const Rect) callconv(.Inline) bool {
        return a != null and b != null and (a.?.x == b.?.x) and
            (a.?.y == b.?.y) and (a.?.w == b.?.w) and (a.?.h == b.?.h);
    }
    pub extern fn SDL_HasIntersection(a: *const Rect, b: *const Rect) callconv(CC) IntBool;
    pub extern fn SDL_IntersectRect(a: *const Rect, b: *const Rect, result: *Rect) callconv(CC) IntBool;
    pub extern fn SDL_UnionRect(a: *const Rect, b: *const Rect, result: *Rect) callconv(CC) void;
    pub extern fn SDL_EnclosePoints(points: ?[*]const Point, count: i32, clip: ?*const Rect, result: *Rect) callconv(CC) IntBool;
    pub extern fn SDL_IntersectRectAndLine(rect: *const Rect, x1: *i32, y1: *i32, x2: *i32, y2: *i32) callconv(CC) IntBool;

    // --------------------------- SDL_render.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetNumRenderDrivers() callconv(CC) i32;
    pub extern fn SDL_GetRenderDriver(index: i32, info: *Renderer.Info) callconv(CC) c_int;
    pub extern fn SDL_CreateWindowAndRenderer(width: i32, height: i32, flags: Window.Flags.Int, window: *?*Window, renderer: *?*Renderer) callconv(CC) c_int;
    pub extern fn SDL_CreateRenderer(window: *Window, index: i32, flags: Renderer.Flags.Int) callconv(CC) ?*Renderer;
    pub extern fn SDL_CreateSoftwareRenderer(surface: *Surface) callconv(CC) ?*Renderer;
    pub extern fn SDL_GetRenderer(window: *Window) callconv(CC) ?*Renderer;
    pub extern fn SDL_GetRendererInfo(renderer: *Renderer, info: *Renderer.Info) callconv(CC) c_int;
    pub extern fn SDL_GetRendererOutputSize(renderer: *Renderer, w: *i32, h: *i32) callconv(CC) c_int;
    pub extern fn SDL_CreateTexture(renderer: *Renderer, format: Format, access: Texture.Access, w: i32, h: i32) callconv(CC) ?*Texture;
    pub extern fn SDL_CreateTextureFromSurface(renderer: *Renderer, surface: *Surface) callconv(CC) ?*Texture;
    pub extern fn SDL_QueryTexture(texture: *Texture, format: *Format, access: *Texture.Access, w: *i32, h: *i32) callconv(CC) c_int;
    pub extern fn SDL_SetTextureColorMod(texture: *Texture, r: u8, g: u8, b: u8) callconv(CC) c_int;
    pub extern fn SDL_GetTextureColorMod(texture: *Texture, r: *u8, g: *u8, b: *u8) callconv(CC) c_int;
    pub extern fn SDL_SetTextureAlphaMod(texture: *Texture, alpha: u8) callconv(CC) c_int;
    pub extern fn SDL_GetTextureAlphaMod(texture: *Texture, alpha: *u8) callconv(CC) c_int;
    pub extern fn SDL_SetTextureBlendMode(texture: *Texture, blendMode: BlendMode) callconv(CC) c_int;
    pub extern fn SDL_GetTextureBlendMode(texture: *Texture, blendMode: *BlendMode) callconv(CC) c_int;
    pub extern fn SDL_SetTextureScaleMode(texture: *Texture, scaleMode: Texture.ScaleMode) callconv(CC) c_int;
    pub extern fn SDL_GetTextureScaleMode(texture: *Texture, scaleMode: *Texture.ScaleMode) callconv(CC) c_int;
    pub extern fn SDL_UpdateTexture(texture: *Texture, rect: ?*const Rect, pixels: *const anyopaque, pitch: i32) callconv(CC) c_int;
    pub extern fn SDL_UpdateYUVTexture(
        texture: *Texture,
        rect: ?*const Rect,
        yPlane: [*]const u8, yPitch: i32,
        uPlane: [*]const u8, uPitch: i32,
        vPlane: [*]const u8, vPitch: i32,
    ) callconv(CC) c_int;
    pub extern fn SDL_LockTexture(texture: *Texture, rect: ?*const Rect, pixels: *?*anyopaque, pitch: i32) callconv(CC) c_int;
    pub extern fn SDL_LockTextureToSurface(texture: *Texture, rect: ?*const Rect, surface: *?*Surface) callconv(CC) c_int;
    pub extern fn SDL_UnlockTexture(texture: *Texture) callconv(CC) void;

    pub extern fn SDL_RenderTargetSupported(renderer: *Renderer) callconv(CC) IntBool;
    pub extern fn SDL_SetRenderTarget(renderer: *Renderer, texture: ?*Texture) callconv(CC) c_int;
    pub extern fn SDL_GetRenderTarget(renderer: *Renderer) callconv(CC) ?*Texture;
    pub extern fn SDL_RenderSetLogicalSize(renderer: *Renderer, w: i32, h: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderGetLogicalSize(renderer: *Renderer, w: *i32, h: *i32) callconv(CC) void;
    pub extern fn SDL_RenderSetIntegerScale(renderer: *Renderer, enable: IntBool) callconv(CC) c_int;
    pub extern fn SDL_RenderGetIntegerScale(renderer: *Renderer) callconv(CC) IntBool;
    pub extern fn SDL_RenderSetViewport(renderer: *Renderer, rect: ?*const Rect) callconv(CC) c_int;
    pub extern fn SDL_RenderGetViewport(renderer: *Renderer, rect: *Rect) callconv(CC) void;
    pub extern fn SDL_RenderSetClipRect(renderer: *Renderer, rect: ?*const Rect) callconv(CC) c_int;
    pub extern fn SDL_RenderGetClipRect(renderer: *Renderer, rect: *Rect) callconv(CC) void;
    pub extern fn SDL_RenderIsClipEnabled(renderer: *Renderer) callconv(CC) IntBool;
    pub extern fn SDL_RenderSetScale(renderer: *Renderer, scaleX: f32, scaleY: f32) callconv(CC) c_int;
    pub extern fn SDL_RenderGetScale(renderer: *Renderer, scaleX: *f32, scaleY: *f32) callconv(CC) void;
    pub extern fn SDL_SetRenderDrawColor(renderer: *Renderer, r: u8, g: u8, b: u8, a: u8) callconv(CC) c_int;
    pub extern fn SDL_GetRenderDrawColor(renderer: *Renderer, r: *u8, g: *u8, b: *u8, a: *u8) callconv(CC) c_int;
    pub extern fn SDL_SetRenderDrawBlendMode(renderer: *Renderer, blendMode: BlendMode) callconv(CC) c_int;
    pub extern fn SDL_GetRenderDrawBlendMode(renderer: *Renderer, blendMode: *BlendMode) callconv(CC) c_int;
    pub extern fn SDL_RenderClear(renderer: *Renderer) callconv(CC) c_int;

    pub extern fn SDL_RenderDrawPoint(renderer: *Renderer, x: i32, y: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawPoints(renderer: *Renderer, points: ?[*]const Point, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawLine(renderer: *Renderer, x1: i32, y1: i32, x2: i32, y2: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawLines(renderer: *Renderer, points: ?[*]const Point, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawRect(renderer: *Renderer, rect: ?*const Rect) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawRects(renderer: *Renderer, rects: ?[*]const Rect, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderFillRect(renderer: *Renderer, rect: ?*const Rect) callconv(CC) c_int;
    pub extern fn SDL_RenderFillRects(renderer: *Renderer, rects: ?[*]const Rect, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderCopy(renderer: *Renderer, texture: *Texture, srcrect: ?*const Rect, dstrect: ?*const Rect) callconv(CC) c_int;
    pub extern fn SDL_RenderCopyEx(
        renderer: *Renderer,
        texture: *Texture,
        srcrect: ?*const Rect,
        dstrect: ?*const Rect,
        angle: f64,
        center: ?*const Point,
        flip: Renderer.Flip.Int,
    ) callconv(CC) c_int;

    pub extern fn SDL_RenderDrawPointF(renderer: *Renderer, x: f32, y: f32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawPointsF(renderer: *Renderer, points: ?[*]const FPoint, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawLineF(renderer: *Renderer, x1: f32, y1: f32, x2: f32, y2: f32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawLinesF(renderer: *Renderer, points: ?[*]const FPoint, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawRectF(renderer: *Renderer, rect: ?*const FRect) callconv(CC) c_int;
    pub extern fn SDL_RenderDrawRectsF(renderer: *Renderer, rects: ?[*]const FRect, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderFillRectF(renderer: *Renderer, rect: ?*const FRect) callconv(CC) c_int;
    pub extern fn SDL_RenderFillRectsF(renderer: *Renderer, rects: ?[*]const FRect, count: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderCopyF(renderer: *Renderer, texture: *Texture, srcrect: ?*const Rect, dstrect: ?*const FRect) callconv(CC) c_int;
    pub extern fn SDL_RenderCopyExF(
        renderer: *Renderer,
        texture: *Texture,
        srcrect: ?*const Rect,
        dstrect: ?*const FRect,
        angle: f64,
        center: ?*const FPoint,
        flip: Renderer.Flip.Int,
    ) callconv(CC) c_int;

    pub extern fn SDL_RenderReadPixels(renderer: *Renderer, rect: ?*const Rect, format: Format, pixels: *anyopaque, pitch: i32) callconv(CC) c_int;
    pub extern fn SDL_RenderPresent(renderer: *Renderer) callconv(CC) void;
    pub extern fn SDL_DestroyTexture(texture: *Texture) callconv(CC) void;
    pub extern fn SDL_DestroyRenderer(renderer: *Renderer) callconv(CC) void;
    pub extern fn SDL_RenderFlush(renderer: *Renderer) callconv(CC) c_int;

    pub extern fn SDL_GL_BindTexture(texture: *Texture, texw: *f32, texh: *f32) callconv(CC) c_int;
    pub extern fn SDL_GL_UnbindTexture(texture: *Texture) callconv(CC) c_int;

    pub extern fn SDL_RenderGetMetalLayer(renderer: *Renderer) callconv(CC) ?*anyopaque;
    pub extern fn SDL_RenderGetMetalCommandEncoder(renderer: *Renderer) callconv(CC) ?*anyopaque;

    // --------------------------- SDL_rwops.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_RWFromFile(file: ?[*:0]const u8, mode: ?[*:0]const u8) callconv(CC) ?*RWops;
    pub extern fn SDL_RWFromFP(fp: ?*anyopaque, autoclose: IntBool) callconv(CC) ?*RWops;
    pub extern fn SDL_RWFromMem(mem: ?*anyopaque, size: i32) callconv(CC) ?*RWops;
    pub extern fn SDL_RWFromConstMem(mem: ?*const anyopaque, size: i32) callconv(CC) ?*RWops;
    pub extern fn SDL_AllocRW() callconv(CC) ?*RWops;
    pub extern fn SDL_FreeRW(area: *RWops) callconv(CC) void;
    pub extern fn SDL_RWsize(context: *RWops) callconv(CC) i64;
    pub extern fn SDL_RWseek(context: *RWops, offset: i64, whence: RWops.Whence) callconv(CC) i64;
    pub extern fn SDL_RWtell(context: *RWops) callconv(CC) i64;
    pub extern fn SDL_RWread(context: *RWops, ptr: ?*anyopaque, size: usize, maxnum: usize) callconv(CC) usize;
    pub extern fn SDL_RWwrite(context: *RWops, ptr: ?*anyopaque, size: usize, num: usize) callconv(CC) usize;
    pub extern fn SDL_RWclose(context: *RWops) callconv(CC) i32;
    pub extern fn SDL_LoadFile_RW(src: *RWops, datasize: ?*usize, freesrc: i32) callconv(CC) ?*anyopaque;
    pub extern fn SDL_LoadFile(file: ?[*:0]const u8, datasize: ?*usize) callconv(CC) ?*anyopaque;

    pub extern fn SDL_ReadU8(src: *RWops) callconv(CC) u8;
    pub extern fn SDL_ReadLE16(src: *RWops) callconv(CC) u16;
    pub extern fn SDL_ReadBE16(src: *RWops) callconv(CC) u16;
    pub extern fn SDL_ReadLE32(src: *RWops) callconv(CC) u32;
    pub extern fn SDL_ReadBE32(src: *RWops) callconv(CC) u32;
    pub extern fn SDL_ReadLE64(src: *RWops) callconv(CC) u64;
    pub extern fn SDL_ReadBE64(src: *RWops) callconv(CC) u64;

    pub extern fn SDL_WriteU8(dst: *RWops, value: u8) callconv(CC) usize;
    pub extern fn SDL_WriteLE16(dst: *RWops, value: u16) callconv(CC) usize;
    pub extern fn SDL_WriteBE16(dst: *RWops, value: u16) callconv(CC) usize;
    pub extern fn SDL_WriteLE32(dst: *RWops, value: u32) callconv(CC) usize;
    pub extern fn SDL_WriteBE32(dst: *RWops, value: u32) callconv(CC) usize;
    pub extern fn SDL_WriteLE64(dst: *RWops, value: u64) callconv(CC) usize;
    pub extern fn SDL_WriteBE64(dst: *RWops, value: u64) callconv(CC) usize;

    // --------------------------- SDL_sensor.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_LockSensors() callconv(CC) void;
    pub extern fn SDL_UnlockSensors() callconv(CC) void;

    pub extern fn SDL_NumSensors() callconv(CC) i32;
    pub extern fn SDL_SensorGetDeviceName(device_index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_SensorGetDeviceType(device_index: i32) callconv(CC) Sensor.Type;
    pub extern fn SDL_SensorGetDeviceNonPortableType(device_index: i32) callconv(CC) i32;
    pub extern fn SDL_SensorGetDeviceInstanceID(device_index: i32) callconv(CC) Sensor.ID;
    pub extern fn SDL_SensorOpen(device_index: i32) callconv(CC) ?*Sensor;
    pub extern fn SDL_SensorGetName(sensor: *Sensor) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_SensorGetType(sensor: *Sensor) callconv(CC) Sensor.Type;
    pub extern fn SDL_SensorGetNonPortableType(sensor: *Sensor) callconv(CC) i32;
    pub extern fn SDL_SensorGetInstanceID(sensor: *Sensor) callconv(CC) Sensor.ID;
    pub extern fn SDL_SensorGetData(sensor: *Sensor, data: [*]f32, num_values: i32) callconv(CC) c_int;
    pub extern fn SDL_SensorClose(sensor: *Sensor) callconv(CC) void;

    pub extern fn SDL_SensorUpdate() callconv(CC) void;

    // --------------------------- SDL_shape.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_CreateShapedWindow(
        title: [*:0]const u8,
        x: u32,
        y: u32,
        w: u32,
        h: u32,
        flags: Window.Flags.Int,
    ) callconv(CC) ?*Window;
    pub extern fn SDL_IsShapedWindow(window: *Window) callconv(CC) IntBool;
    pub fn SDL_SHAPEMODEALPHA(mode: Window.ShapeMode.Type) callconv(.Inline) bool {
        return mode == .default
            or mode == .binarize_alpha
            or mode == .reverse_binarize_alpha;
    }
    pub extern fn SDL_SetWindowShape(window: *Window, shape: *Surface, mode: *const Window.ShapeMode) callconv(CC) c_int;
    pub extern fn SDL_GetShapedWindowMode(window: *Window, mode: *Window.ShapeMode) callconv(CC) c_int;

    // --------------------------- SDL_surface.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_CreateRGBSurface(
        flags: Surface.Flags.Int,
        width: i32,
        height: i32,
        depth: i32,
        rmask: u32,
        gmask: u32,
        bmask: u32,
        amask: u32,
    ) callconv(CC) ?*Surface;
    pub extern fn SDL_CreateRGBSurfaceWithFormat(
        flags: Surface.Flags.Int,
        width: i32,
        height: i32,
        depth: i32,
        format: Format,
    ) callconv(CC) ?*Surface;
    pub extern fn SDL_CreateRGBSurfaceFrom(
        pixels: ?*anyopaque,
        width: i32,
        height: i32,
        depth: i32,
        pitch: i32,
        rmask: u32,
        gmask: u32,
        bmask: u32,
        amask: u32,
    ) callconv(CC) ?*Surface;
    pub extern fn SDL_CreateRGBSurfaceWithFormatFrom(
        pixels: ?*anyopaque,
        width: i32,
        height: i32,
        depth: i32,
        pitch: i32,
        format: Format,
    ) callconv(CC) ?*Surface;
    pub extern fn SDL_FreeSurface(surface: *Surface) callconv(CC) void;
    pub extern fn SDL_SetSurfacePalette(surface: *Surface, palette: *const Palette) callconv(CC) c_int;
    pub extern fn SDL_LockSurface(surface: *Surface) callconv(CC) c_int;
    pub extern fn SDL_UnlockSurface(surface: *Surface) callconv(CC) void;
    pub extern fn SDL_LoadBMP_RW(src: *RWops, freesrc: IntBool) callconv(CC) ?*Surface;
    pub fn SDL_LoadBMP(file: [*:0]const u8) callconv(.Inline) ?*Surface {
        const rw = SDL_RWFromFile(file, "rb") orelse return null;
        return SDL_LoadBMP_RW(rw, 1);
    }
    pub extern fn SDL_SaveBMP_RW(surface: *Surface, dst: *RWops, freedst: IntBool) callconv(CC) c_int;
    pub fn SDL_SaveBMP(surface: *Surface, file: [*:0]const u8) callconv(.Inline) c_int {
        const rw = SDL_RWFromFile(file, "wb") orelse return -1;
        return SDL_SaveBMP_RW(surface, rw, 1);
    }
    pub extern fn SDL_SetSurfaceRLE(surface: *Surface, flag: IntBool) callconv(CC) c_int;
    pub extern fn SDL_HasSurfaceRLE(surface: *Surface) callconv(CC) IntBool;
    pub extern fn SDL_SetColorKey(surface: *Surface, flag: IntBool, key: u32) callconv(CC) c_int;
    pub extern fn SDL_HasColorKey(surface: *Surface) callconv(CC) IntBool;
    pub extern fn SDL_GetColorKey(surface: *Surface, key: *u32) callconv(CC) c_int;
    pub extern fn SDL_SetSurfaceColorMod(surface: *Surface, r: u8, g: u8, b: u8) callconv(CC) c_int;
    pub extern fn SDL_GetSurfaceColorMod(surface: *Surface, r: *u8, g: *u8, b: *u8) callconv(CC) c_int;
    pub extern fn SDL_SetSurfaceAlphaMod(surface: *Surface, alpha: u8) callconv(CC) c_int;
    pub extern fn SDL_GetSurfaceAlphaMod(surface: *Surface, alpha: *u8) callconv(CC) c_int;
    pub extern fn SDL_SetSurfaceBlendMode(surface: *Surface, blendMode: BlendMode) callconv(CC) c_int;
    pub extern fn SDL_GetSurfaceBlendMode(surface: *Surface, blendMode: *BlendMode) callconv(CC) c_int;
    pub extern fn SDL_SetClipRect(surface: *Surface, rect: ?*const Rect) callconv(CC) IntBool;
    pub extern fn SDL_GetClipRect(surface: *Surface, rect: *Rect) callconv(CC) void;
    pub extern fn SDL_DuplicateSurface(surface: *Surface) callconv(CC) ?*Surface;
    pub extern fn SDL_ConvertSurface(src: *Surface, fmt: *const PixelFormat, flags: Surface.Flags.Int) callconv(CC) ?*Surface;
    pub extern fn SDL_ConvertSurfaceFormat(src: *Surface, pixel_format: Format, flags: Surface.Flags.Int) callconv(CC) ?*Surface;
    pub extern fn SDL_ConvertPixels(
        width: i32,
        height: i32,
        src_format: Format,
        src: *const anyopaque,
        src_pitch: i32,
        dst_format: Format,
        dst: *anyopaque,
        dst_pitch: i32,
    ) callconv(CC) c_int;
    pub extern fn SDL_FillRect(dst: *Surface, rect: ?*const Rect, color: u32) callconv(CC) c_int;
    pub extern fn SDL_FillRects(dst: *Surface, rects: ?[*]const Rect, count: i32, color: u32) callconv(CC) c_int;
    pub const SDL_BlitSurface = SDL_UpperBlit;
    pub extern fn SDL_UpperBlit(src: *Surface, srcrect: ?*const Rect, dst: *Surface, dstrect: ?*Rect) callconv(CC) c_int;
    pub extern fn SDL_LowerBlit(src: *Surface, srcrect: ?*Rect, dst: *Surface, dstrect: ?*Rect) callconv(CC) c_int;
    pub extern fn SDL_SoftStretch(src: *Surface, srcrect: ?*const Rect, dst: *Surface, dstrect: ?*const Rect) callconv(CC) c_int;
    pub const SDL_BlitScaled = SDL_UpperBlitScaled;
    pub extern fn SDL_UpperBlitScaled(src: *Surface, srcrect: ?*const Rect, dst: *Surface, dstrect: ?*Rect) callconv(CC) c_int;
    pub extern fn SDL_LowerBlitScaled(src: *Surface, srcrect: ?*Rect, dst: *Surface, dstrect: ?*Rect) callconv(CC) c_int;
    pub extern fn SDL_SetYUVConversionMode(mode: YuvConversionMode) callconv(CC) void;
    pub extern fn SDL_GetYUVConversionMode() callconv(CC) YuvConversionMode;
    pub extern fn SDL_GetYUVConversionModeForResolution(width: i32, height: i32) callconv(CC) YuvConversionMode;

    // --------------------------- SDL_system.h --------------------------
    // [ ] Wrappers
    pub const windows = struct {
        pub const WindowsMessageHook = fn(userdata: ?*anyopaque, hwnd: ?*anyopaque, message: u32, wParam: u16, lParam: i64) callconv(CC) void;
        pub extern fn SDL_SetWindowsMessageHook(callback: ?WindowsMessageHook, userdata: ?*anyopaque) callconv(CC) void;
        pub extern fn SDL_Direct3D9GetAdapterIndex(displayIndex: i32) callconv(CC) i32;
        pub const IDirect3DDevice9 = opaque{};
        pub extern fn SDL_RenderGetD3D9Device(renderer: *Renderer) callconv(CC) ?*IDirect3DDevice9;
        pub extern fn SDL_DXGIGetOutputInfo(displayIndex: i32, adapterIndex: *i32, outputIndex: *i32) callconv(CC) IntBool;
    };
    pub const linux = struct {
        pub extern fn SDL_LinuxSetThreadPriority(threadID: i64, priority: i32) callconv(CC) c_int;
    };
    pub const iphoneos = struct {
        pub const SDL_iOSSetAnimationCallback = SDL_iPhoneSetAnimationCallback;
        pub extern fn SDL_iPhoneSetAnimationCallback(window: *Window, interval: i32, callback: ?fn(?*anyopaque) callconv(.C) void, callbackParam: ?*anyopaque) callconv(CC) c_int;
        pub const SDL_iOSSetEventPump = SDL_iPhoneSetEventPump;
        pub extern fn SDL_iPhoneSetEventPump(enabled: IntBool) callconv(CC) void;
    };
    pub const android = struct {
        pub extern fn SDL_AndroidGetJNIEnv() callconv(CC) ?*anyopaque;
        pub extern fn SDL_AndroidGetActivity() callconv(CC) ?*anyopaque;
        pub extern fn SDL_GetAndroidSDKVersion() callconv(CC) i32;
        pub extern fn SDL_IsAndroidTV() callconv(CC) IntBool;
        pub extern fn SDL_IsChromebook() callconv(CC) IntBool;
        pub extern fn SDL_IsDeXMode() callconv(CC) IntBool;
        pub extern fn SDL_AndroidBackButton() callconv(CC) void;
        pub extern fn SDL_AndroidGetInternalStoragePath() callconv(CC) ?[*:0]const u8;
        // TODO: put this somewhere else, not in extern declarations.
        pub const AndroidExternalStorageState = packed struct {
            read: bool = false,
            write: bool = false,
            __pad: u30 = 0,

            pub const Int = u32;
            pub fn toInt(self: @This()) Int {
                return @bitCast(Int, self);
            }
            pub fn fromInt(int: Int) @This() {
                return @bitCast(@This(), int);
            }

            pub fn isAvailable(self: @This()) bool {
                return self.toInt() != 0;
            }
        };
        pub extern fn SDL_AndroidGetExternalStorageState() callconv(CC) AndroidExternalStorageState.Int;
        pub extern fn SDL_AndroidGetExternalStoragePath() callconv(CC) ?[*:0]const u8;
        pub extern fn SDL_AndroidRequestPermission(permission: [*:0]const u8) callconv(CC) IntBool;
    };
    pub const winrt = struct {
        pub const WinRTPath = enum(u32) {
            installed_location,
            local_folder,
            roaming_folder,
            temp_folder,
            _,
        };
        pub const WinRTDeviceFamily = enum(u32) {
            unknown,
            desktop,
            mobile,
            xbox,
            _,
        };
        pub extern fn SDL_WinRTGetFSPathUNICODE(path: WinRTPath) callconv(CC) ?[*:0]const u16;
        pub extern fn SDL_WinRTGetFSPathUTF8(path: WinRTPath) callconv(CC) ?[*:0]const u8;
        pub extern fn SDL_WinRTGetDeviceFamily() callconv(CC) WinRTDeviceFamily;
    };
    pub extern fn SDL_IsTablet() callconv(CC) IntBool;

    // --------------------------- SDL_syswm.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetWindowWMInfo(window: *Window, info: *SysWMinfo) callconv(CC) IntBool;

    // --------------------------- SDL_timer.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetTicks() callconv(CC) u32;
    pub fn SDL_TICKS_PASSED(a: u32, b: u32) callconv(.Inline) bool {
        return @bitCast(i32, b) - @bitCast(i32, a) <= 0; 
    }
    pub extern fn SDL_GetPerformanceCounter() callconv(CC) u64;
    pub extern fn SDL_GetPerformanceFrequency() callconv(CC) u64;
    pub extern fn SDL_Delay(ms: u32) callconv(CC) void;
    pub extern fn SDL_AddTimer(interval: u32, callback: TimerCallback, param: ?*anyopaque) callconv(CC) TimerID;
    pub extern fn SDL_RemoveTimer(id: TimerID) IntBool;

    // --------------------------- SDL_touch.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetNumTouchDevices() callconv(CC) i32;
    pub extern fn SDL_GetTouchDevice(index: i32) callconv(CC) TouchID;
    pub extern fn SDL_GetTouchDeviceType(touchID: TouchID) callconv(CC) TouchDeviceType;
    pub extern fn SDL_GetNumTouchFingers(touchID: TouchID) callconv(CC) i32;
    pub extern fn SDL_GetTouchFinger(touchID: TouchID, index: i32) callconv(CC) ?*Finger;

    // --------------------------- SDL_video.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetVersion(ver: *Version) callconv(CC) void;
    pub extern fn SDL_GetRevision() callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetRevisionNumber() callconv(CC) i32;

    // --------------------------- SDL_video.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_GetNumVideoDrivers() callconv(CC) i32;
    pub extern fn SDL_GetVideoDriver(index: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_VideoInit(driver_name: ?[*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_VideoQuit() callconv(CC) void;
    pub extern fn SDL_GetCurrentVideoDriver() callconv(CC) ?[*:0]const u8;
    
    pub extern fn SDL_GetNumVideoDisplays() callconv(CC) i32;
    pub extern fn SDL_GetDisplayName(displayIndex: i32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetDisplayBounds(displayIndex: i32, rect: *Rect) callconv(CC) c_int;
    pub extern fn SDL_GetDisplayUsableBounds(displayIndex: i32, rect: *Rect) callconv(CC) c_int;
    pub extern fn SDL_GetDisplayDPI(displayIndex: i32, ddpi: *f32, hdpi: *f32, vdpi: *f32) callconv(CC) c_int;
    pub extern fn SDL_GetDisplayOrientation(displayIndex: i32) callconv(CC) video.DisplayOrientation.Int;
    pub extern fn SDL_GetNumDisplayModes(displayIndex: i32) callconv(CC) i32;
    pub extern fn SDL_GetDisplayMode(displayIndex: i32, modeIndex: i32, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetDesktopDisplayMode(displayIndex: i32, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetCurrentDisplayMode(displayIndex: i32, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetClosestDisplayMode(displayIndex: i32, mode: *const video.DisplayMode, closest: *video.DisplayMode) callconv(CC) ?*video.DisplayMode;
    
    pub extern fn SDL_GetWindowDisplayIndex(window: *Window) callconv(CC) c_int;
    pub extern fn SDL_SetWindowDisplayMode(window: *Window, mode: *const video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetWindowDisplayMode(window: *Window, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetWindowPixelFormat(window: *Window) callconv(CC) Format;
    pub extern fn SDL_CreateWindow(title: ?[*:0]const u8, x: i32, y: i32, w: i32, h: i32, flags: Window.Flags.Int) callconv(CC) ?*Window;
    pub extern fn SDL_CreateWindowFrom(data: ?*anyopaque) callconv(CC) ?*Window;
    pub extern fn SDL_GetWindowID(window: *Window) callconv(CC) u32;
    pub extern fn SDL_GetWindowFromID(id: u32) callconv(CC) ?*Window;
    pub extern fn SDL_GetWindowFlags(window: *Window) callconv(CC) Window.Flags.Int;
    pub extern fn SDL_SetWindowTitle(window: *Window, title: ?[*:0]const u8) callconv(CC) void;
    pub extern fn SDL_GetWindowTitle(window: *Window) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_SetWindowIcon(window: *Window, icon: *Surface) callconv(CC) void;
    pub extern fn SDL_SetWindowData(window: *Window, name: [*:0]const u8, userdata: ?*anyopaque) callconv(CC) ?*anyopaque;
    pub extern fn SDL_GetWindowData(window: *Window, name: [*:0]const u8) callconv(CC) ?*anyopaque;
    pub extern fn SDL_SetWindowPosition(window: *Window, x: i32, y: i32) callconv(CC) void;
    pub extern fn SDL_GetWindowPosition(window: *Window, x: ?*i32, y: ?*i32) callconv(CC) void;
    pub extern fn SDL_SetWindowSize(window: *Window, w: i32, h: i32) callconv(CC) void;
    pub extern fn SDL_GetWindowSize(window: *Window, w: ?*i32, h: ?*i32) callconv(CC) void;
    pub extern fn SDL_GetWindowBordersSize(window: *Window, top: ?*i32, left: ?*i32, bottom: ?*i32, right: ?*i32) callconv(CC) c_int;
    pub extern fn SDL_SetWindowMinimumSize(window: *Window, min_w: i32, min_h: i32) callconv(CC) void;
    pub extern fn SDL_GetWindowMinimumSize(window: *Window, w: ?*i32, h: ?*i32) callconv(CC) void;
    pub extern fn SDL_SetWindowMaximumSize(window: *Window, max_w: i32, max_h: i32) callconv(CC) void;
    pub extern fn SDL_GetWindowMaximumSize(window: *Window, w: ?*i32, h: ?*i32) callconv(CC) void;
    pub extern fn SDL_SetWindowBordered(window: *Window, bordered: IntBool) callconv(CC) void;
    pub extern fn SDL_SetWindowResizable(window: *Window, resizable: IntBool) callconv(CC) void;
    pub extern fn SDL_ShowWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_HideWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_RaiseWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_MaximizeWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_MinimizeWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_RestoreWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_SetWindowFullscreen(window: *Window, flags: Window.Flags.Int) callconv(CC) c_int;
    pub extern fn SDL_GetWindowSurface(window: *Window) callconv(CC) ?*Surface;
    pub extern fn SDL_UpdateWindowSurface(window: *Window) callconv(CC) c_int;
    pub extern fn SDL_UpdateWindowSurfaceRects(window: *Window, rects: ?[*]const Rect, numrects: i32) callconv(CC) c_int;
    pub extern fn SDL_SetWindowGrab(window: *Window, grabbed: IntBool) callconv(CC) void;
    pub extern fn SDL_GetWindowGrab(window: *Window) callconv(CC) IntBool;
    pub extern fn SDL_GetGrabbedWindow() callconv(CC) ?*Window;
    pub extern fn SDL_SetWindowBrightness(window: *Window, brightness: f32) callconv(CC) c_int;
    pub extern fn SDL_GetWindowBrightness(window: *Window) callconv(CC) f32;
    pub extern fn SDL_SetWindowOpacity(window: *Window, opacity: f32) callconv(CC) c_int;
    pub extern fn SDL_GetWindowOpacity(window: *Window, out_opacity: *f32) callconv(CC) c_int;
    pub extern fn SDL_SetWindowModalFor(modal_window: *Window, parent_window: *Window) callconv(CC) c_int;
    pub extern fn SDL_SetWindowInputFocus(window: *Window) callconv(CC) c_int;
    pub extern fn SDL_SetWindowGammaRamp(window: *Window, red: ?*const [256]u16, green: ?*const [256]u16, blue: ?*const [256]u16) callconv(CC) c_int;
    pub extern fn SDL_GetWindowGammaRamp(window: *Window, red: ?*[256]u16, green: ?*[256]u16, blue: ?*[256]u16) callconv(CC) c_int;
    pub extern fn SDL_SetWindowHitTest(window: *Window, callback: ?Window.HitTest, callback_data: ?*anyopaque) callconv(CC) c_int;
    pub extern fn SDL_DestroyWindow(window: *Window) callconv(CC) void;

    pub extern fn SDL_IsScreenSaverEnabled() callconv(CC) IntBool;
    pub extern fn SDL_EnableScreenSaver() callconv(CC) void;
    pub extern fn SDL_DisableScreenSaver() callconv(CC) void;

    pub extern fn SDL_GL_LoadLibrary(path: ?[*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_GL_GetProcAddress(proc: [*:0]const u8) callconv(CC) ?*anyopaque;
    pub extern fn SDL_GL_UnloadLibrary() callconv(CC) void;
    pub extern fn SDL_GL_ExtensionSupported(extension: [*:0]const u8) callconv(CC) IntBool;
    pub extern fn SDL_GL_ResetAttributes() callconv(CC) void;
    pub extern fn SDL_GL_SetAttribute(attr: gl.Attr, value: i32) callconv(CC) c_int;
    pub extern fn SDL_GL_GetAttribute(attr: gl.Attr, value: *i32) callconv(CC) c_int;
    pub extern fn SDL_GL_CreateContext(window: *Window) callconv(CC) ?gl.Context;
    pub extern fn SDL_GL_MakeCurrent(window: *Window, context: gl.Context) callconv(CC) c_int;
    pub extern fn SDL_GL_GetCurrentWindow() callconv(CC) ?*Window;
    pub extern fn SDL_GL_GetCurrentContext() callconv(CC) ?gl.Context;
    pub extern fn SDL_GL_GetDrawableSize(window: *Window, w: ?*i32, h: ?*i32) callconv(CC) void;
    pub extern fn SDL_GL_SetSwapInterval(interval: gl.SwapInterval) callconv(CC) c_int;
    pub extern fn SDL_GL_GetSwapInterval() callconv(CC) gl.SwapInterval;
    pub extern fn SDL_GL_SwapWindow(window: *Window) callconv(CC) void;
    pub extern fn SDL_GL_DeleteContext(context: gl.Context) callconv(CC) void;

    // --------------------------- SDL_vulkan.h --------------------------
    // [ ] Wrappers
    pub extern fn SDL_Vulkan_LoadLibrary(path: ?[*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_Vulkan_GetVkGetInstanceProcAddr() callconv(CC) ?*anyopaque;
    pub extern fn SDL_Vulkan_UnloadLibrary() callconv(CC) void;
    pub extern fn SDL_Vulkan_GetInstanceExtensions(window: *Window, pCount: *u32, pNames: ?[*][*:0]const u8) callconv(CC) IntBool;
    pub extern fn SDL_Vulkan_CreateSurface(window: *Window, instance: vk.Instance, surface: *vk.SurfaceKHR) callconv(CC) IntBool;
    pub extern fn SDL_Vulkan_GetDrawableSize(window: *Window, w: *i32, h: *i32) callconv(CC) void;
};
