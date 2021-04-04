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

const endian = std.builtin.endian;

pub const CC = std.builtin.CallingConvention.C;

pub const IntBool = c_int;

pub const Point = struct { x: i32, y: i32 };
pub const FPoint = struct { x: f32, y: f32 };
pub const Rect = struct { x: i32, y: i32, w: i32, h: i32 };
pub const FRect = struct { x: f32, y: f32, w: f32, h: f32 };

pub const RWops = extern struct {
    pub const Whence = extern enum(c_int) {
        seek_set = 0,
        seek_cur = 1,
        seek_end = 2,
        _,
    };

    sizeFn: ?fn(context: *RWops) callconv(CC) i64,
    seekFn: ?fn(context: *RWops, offset: i64, whence: Whence) callconv(CC) i64,
    readFn: ?fn(context: *RWops, ptr: *c_void, size: usize, maxnum: usize) callconv(CC) usize,
    writeFn: ?fn(context: *RWops, ptr: *c_void, size: usize, num: usize) callconv(CC) usize,
    closeFn: ?fn(context: *RWops) callconv(CC) i32,

    type: extern enum(u32) {
        unknown,
        winfile,
        stdfile,
        jnifile,
        memory,
        memory_readonly,
    },

    hidden: extern union {
        androidio: extern struct {
            asset: ?*c_void,
        },
        windowsio: (
            if (std.builtin.os.tag == .windows)
                extern struct {
                    append: IntBool,
                    h: ?*c_void,
                    buffer: extern struct {
                        data: ?*c_void,
                        size: usize,
                        left: usize,
                    },
                }
            else
                extern struct {}
        ),
        stdio: extern struct {
            autoclose: IntBool,
            fp: ?*c_void, // FILE*
        },
        mem: extern struct {
            base: [*]u8,
            here: [*]u8,
            stop: [*]u8,
        },
        unknown: extern struct {
            data1: ?*c_void,
            data2: ?*c_void,
        },
    },
};

pub const audio = struct {
    pub const Format = packed struct {
        bit_size: u8 align(2),

        is_float: bool,
        __pad0: u3 = 0,
        is_big_endian: bool,
        __pad1: u2 = 0,
        is_signed: bool,

        pub const U8: Format = .{ .bit_size = 8, .is_float = false, .is_big_endian = false, .is_signed = false };
        pub const S8: Format = .{ .bit_size = 8, .is_float = false, .is_big_endian = false, .is_signed = true };
        pub const U16LSB: Format = .{ .bit_size = 16, .is_float = false, .is_big_endian = false, .is_signed = false };
        pub const S16LSB: Format = .{ .bit_size = 16, .is_float = false, .is_big_endian = false, .is_signed = true };
        pub const U16MSB: Format = .{ .bit_size = 16, .is_float = false, .is_big_endian = true, .is_signed = false };
        pub const S16MSB: Format = .{ .bit_size = 16, .is_float = false, .is_big_endian = true, .is_signed = true };
        pub const U16 = U16LSB;
        pub const S16 = S16LSB;

        pub const S32LSB: Format = .{ .bit_size = 32, .is_float = false, .is_big_endian = false, .is_signed = true };
        pub const S32MSB: Format = .{ .bit_size = 32, .is_float = false, .is_big_endian = true, .is_signed = true };
        pub const S32 = S32LSB;

        pub const F32LSB: Format = .{ .bit_size = 32, .is_float = true, .is_big_endian = false, .is_signed = true };
        pub const F32MSB: Format = .{ .bit_size = 32, .is_float = true, .is_big_endian = true, .is_signed = true };
        pub const F32 = F32LSB;

        pub const U16SYS = if (endian == .Little) U16LSB else U16MSB;
        pub const S16SYS = if (endian == .Little) S16LSB else S16MSB;
        pub const S32SYS = if (endian == .Little) S32LSB else S32MSB;
        pub const F32SYS = if (endian == .Little) F32LSB else F32MSB;

        pub fn toInt(self: Format) FormatInt {
            return @bitCast(FormatInt, self);
        }

        pub fn fromInt(int: FormatInt) Format {
            return @bitCast(Format, int);
        }
    };

    pub const FormatInt = u16;

    pub const AllowChangeFlags = packed struct {
        frequency: bool align(4) = false,
        format: bool = false,
        channels: bool = false,
        samples: bool = false,
        __pad0: u28 = 9,
    };

    pub const Callback = fn(user_data: ?*c_void, stream: [*]u8, len: c_int) callconv(CC) void;

    pub const Spec = extern struct {
        freq: i32,
        format: Format,
        channels: u8,
        silence: u8 = 0,
        samples: u16,
        padding: u16 = 0,
        size: u32 = 0,
        callback: ?Callback = null,
        user_data: ?*c_void = null,
    };

    pub const Filter = fn(cvt: ?*CVT, format: u16) callconv(CC) void;
    pub const CVT_MAX_FILTERS = 9;

    pub const CVT = extern struct {
        needed: i32,
        src_format: Format,
        dst_format: Format,
        rate_incr: f64 align(4),
        buf: ?[*]u8 align(4),
        len: i32,
        len_cvt: i32,
        len_mult: i32,
        len_ratio: f64 align(4),
        filters: [CVT_MAX_FILTERS + 1]?Filter align(4),
        filter_index: i32,
    };

    pub const DeviceID = extern enum(u32) {
        invalid = 0,
        default = 1,
        _,
    };

    pub const Status = extern enum (i32) {
        stopped,
        playing,
        paused,
        _,
    };

    pub const Stream = opaque{};

    pub const MIX_MAXVOLUME = 128;
};

// TODO: make this an enum
pub const PixelFormatEnum = packed struct {
    const Self = @This();

    pub const unknown = fromInt(0);

    pub const index_1_lsb = init(.index_1, .@"4321", .none, 1, 0);
    pub const index_1_msb = init(.index_1, .@"1234", .none, 1, 0);
    pub const index_4_lsb = init(.index_4, .@"4321", .none, 4, 0);
    pub const index_4_msb = init(.index_4, .@"1234", .none, 4, 0);
    pub const index_8 = init(.index_8, .none, .none, 8, 1);

    pub const rgb332 = init(.packed_8, .xrgb, .@"332", 8, 1);    
    pub const xrgb4444 = init(.packed_16, .xrgb, .@"4444", 12, 2);
    pub const xbgr4444 = init(.packed_16, .xbgr, .@"4444", 12, 2);
    pub const xrgb1555 = init(.packed_16, .xrgb, .@"1555", 15, 2);
    pub const xbgr1555 = init(.packed_16, .xbgr, .@"1555", 15, 2);
    
    pub const rgb444 = xrgb4444;
    pub const bgr444 = xbgr4444;
    pub const rgb555 = xrgb1555;
    pub const bgr555 = xbgr1555;
    
    pub const argb4444 = init(.packed_16, .argb, .@"4444", 16, 2);
    pub const rgba4444 = init(.packed_16, .rgba, .@"4444", 16, 2);
    pub const abgr4444 = init(.packed_16, .abgr, .@"4444", 16, 2);
    pub const bgra4444 = init(.packed_16, .bgra, .@"4444", 16, 2);

    pub const argb1555 = init(.packed_16, .argb, .@"1555", 16, 2);
    pub const rgba5551 = init(.packed_16, .rgba, .@"5551", 16, 2);
    pub const abgr1555 = init(.packed_16, .abgr, .@"1555", 16, 2);
    pub const bgra5551 = init(.packed_16, .bgra, .@"5551", 16, 2);

    pub const rgb565 = init(.packed_16, .xrgb, .@"565", 16, 2);
    pub const bgr565 = init(.packed_16, .xbgr, .@"565", 16, 2);

    pub const rgb24 = init(.array_u8, .rgb, .none, 24, 3);
    pub const bgr24 = init(.array_u8, .bgr, .none, 24, 3);

    pub const xrgb8888 = init(.packed_32, .xrgb, .@"8888", 24, 4);
    pub const rgbx8888 = init(.packed_32, .rgbx, .@"8888", 24, 4);
    pub const xbgr8888 = init(.packed_32, .xbgr, .@"8888", 24, 4);
    pub const bgrx8888 = init(.packed_32, .bgrx, .@"8888", 24, 4);
    pub const rgb888 = xrgb8888;
    pub const bgr888 = xbgr8888;

    pub const argb8888 = init(.packed_32, .argb, .@"8888", 32, 4);
    pub const rgba8888 = init(.packed_32, .rgba, .@"8888", 32, 4);
    pub const abgr8888 = init(.packed_32, .abgr, .@"8888", 32, 4);
    pub const bgra8888 = init(.packed_32, .bgra, .@"8888", 32, 4);

    pub const argb2101010 = init(.packed_32, .argb, .@"2101010", 32, 4);

    pub const rgba32 = if (endian == .Little) abgr8888 else rgba8888;
    pub const argb32 = if (endian == .Little) bgra8888 else argb8888;
    pub const bgra32 = if (endian == .Little) argb8888 else bgra8888;
    pub const abgr32 = if (endian == .Little) rgba8888 else abgr8888;

    pub const YV12 = fourcc("YV12");
    pub const IYUV = fourcc("IYUV");
    pub const YUY2 = fourcc("YUY2");
    pub const UYVY = fourcc("UYVY");
    pub const YVYU = fourcc("YVYU");
    pub const NV12 = fourcc("NV12");
    pub const NV21 = fourcc("NV21");
    pub const external_oes = fourcc("OES ");

    pub fn isFourCC(self: Self) bool {
        return (self.toInt() != 0 and self._is_raw != 1);
    }

    pub fn bitsPerPixel(self: Self) u8 {
        return self._bits;
    }

    pub fn bytesPerPixel(self: Self) u8 {
        if (self.isFourCC()) {
            return if (
                self.equals(YUY2) or
                self.equals(UYVY) or
                self.equals(YVYU)
            ) 2 else 1;
        } else {
            return self._bytes;
        }
    }

    pub fn isIndexed(self: Self) bool {
        return !self.isFourCC() and self._type.isIndexedType();
    }
    pub fn isPacked(self: Self) bool {
        return !self.isFourCC() and self._type.isPackedType();
    }
    pub fn isArray(self: Self) bool {
        return !self.isFourCC() and self._type.isArrayType();
    }

    pub fn isAlpha(self: Self) bool {
        if (self.isPacked()) {
            const fmt = @intToEnum(PackedOrder, self._order);
            return fmt == .argb
                or fmt == .rgba
                or fmt == .abgr
                or fmt == .bgra;
        } else if (self.isArray()) {
            const fmt = @intToEnum(ArrayOrder, self._order);
            return fmt == .argb
                or fmt == .rgba
                or fmt == .abgr
                or fmt == .bgra;
        }
        return false;
    }

    _bytes: u8 align(4),

    _bits: u8,

    _layout: PackedLayout,
    _order: u4, // BitmapOrder, PackedOrder, or ArrayOrder, depending on _type.

    _type: Type,
    _is_raw: u4 = 1,

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

    pub const Int = u32;
    pub fn fromInt(int: Int) @This() {
        return @bitCast(@This(), int);
    }
    pub fn toInt(fmt: @This()) Int {
        return @bitCast(Int, fmt);
    }
    pub fn fourcc(str: *const [4]u8) Self {
        return fromInt(std.mem.readIntLittle(u32, str));
    }
    pub fn init(
        comptime _type: Type,
        order: OrderOf(_type),
        layout: PackedLayout,
        bits: u8,
        bytes: u8
    ) Self {
        return .{
            ._bytes = bytes,
            ._bits = bits,
            ._layout = layout,
            ._order = @enumToInt(order),
            ._type = type,
        };
    }

    pub fn equals(self: @This(), other: @This()) bool {
        return self.toInt() == other.toInt();
    }
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
    format: PixelFormatEnum,
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
        fullscreen: bool align(4) = false,
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

        pub fn fromInt(int: Int) @This() {
            return @bitCast(@This(), int);
        }
        pub fn toInt(flags: @This()) Int {
            return @bitCast(Int, flags);
        }

        pub const Int = u32;
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

    pub const HitTestResult = extern enum {
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
        data: ?*c_void
    ) callconv(CC) HitTestResult;

    pub fn create(title: ?[*:0]const u8, x: i32, y: i32, w: i32, h: i32, flags: Flags) callconv(.Inline) !*Window {
        return raw.SDL_CreateWindow(title, x, y, w, h, flags.toInt()) orelse error.SDL_ERROR;
    }
    pub fn createFrom(data: ?*c_void) callconv(.Inline) !*Window {
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
    pub fn getPixelFormat(window: *Window) callconv(.Inline) !PixelFormatEnum {
        const int = raw.SDL_GetWindowPixelFormat(window);
        if (int == 0) return error.SDL_ERROR;
        return PixelFormatEnum.fromInt(int);
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
        if (@sizeOf(DataPtrT) != @sizeOf(?*c_void)) {
            @compileError("DataPtrT must be a real pointer, but is "++@typeName(DataPtrT));
        }
        const gen = struct {
            fn hitTestCallback(win: *Window, area: ?*const Point, data: ?*c_void) callconv(CC) HitTestResult {
                const ptr = @intToPtr(DataPtrT, @ptrToInt(data));
                return callback(win, area, ptr);
            }
        };
        const erased = @intToPtr(?*c_void, @ptrToInt(data));
        const rc = raw.SDL_SetWindowHitTest(window, gen.hitTestCallback, erased);
        if (rc < 0) return error.SDL_ERROR;
    }
};

pub const video = struct {
    pub const DisplayMode = extern struct {
        format: PixelFormatEnum,
        w: i32,
        h: i32,
        refresh_rate: i32 = 0,
        driverdata: ?*c_void = null,
    };

    pub const WindowEvent = extern enum {
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

    pub const DisplayEvent = extern enum {
        none,
        orientation,
        connected,
        disconnected,
        _,
    };

    pub const DisplayOrientation = extern enum {
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
    pub const Attr = extern enum {
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
        core: bool align(2) = false,
        compatibility: bool = false,
        es: bool = false,
        __pad0: u13 = 0,
    };

    pub const ContextFlags = packed struct {
        debug: bool align(2) = false,
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

    pub const SwapInterval = extern enum (c_int) {
        late_swaps = -1,
        vsync_off = 0,
        vsync_on = 1,
        _,
    };
};

pub const Scancode = extern enum (c_int) {
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

pub const Keycode = extern enum (i32) {
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

    pub fn intValueFromScancode(code: Scancode) i32 {
        return @intCast(i32, @enumToInt(code)) | (1<<30);
    }
};

pub const Keymod = packed struct {
    lshift: bool align(2) = false,
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
    mod: Keymod,
    unused: u32 = 0,
};

pub const Joystick = opaque {
    pub const GUID = extern struct {
        data: [16]u8,
    };
    pub const ID = extern enum(i32) { invalid = -1, _ };

    pub const Type = extern enum {
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
    };

    pub const PowerLevel = extern enum {
        unknown = -1,
        empty,
        low,
        medium,
        full,
        wired,
        max,
    };

    pub const IPHONE_MAX_GFORCE = 5.0;

    pub const AXIS_MAX = 32767;
    pub const AXIS_MIN = -32768;

    pub const Hat = extern enum (u8) {
        centered = 0,
        up = 1,
        right = 2,
        down = 4,
        left = 8,
        rightup = 3,
        rightdown = 6,
        leftup = 9,
        leftdown = 12,

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

pub const TouchID = extern enum(i64) { mouse = -1, _ };
pub const FingerID = extern enum(i64) { _ };
pub const TouchDeviceType = extern enum {
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

pub const GestureID = extern enum(i64) { _ };

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

    pub const Type = extern enum(u32) {
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
        data1: ?*c_void,
        data2: ?*c_void,
    };

    pub const SysWMEvent = extern struct {
        type: Type,
        timestamp: u32,
        msg: ?*SysWMmsg,

        pub const SysWMmsg = opaque{};
    };

    pub const Action = extern enum {
        add,
        peek,
        get,
        _,
    };

    pub const State = extern enum {
        query = -1,
        ignore = 0,
        disable = 0,
        enable = 1,
    };

    pub const Filter = fn(userdata: ?*c_void, event: *Event) callconv(CC) IntBool;

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
        var count: u32 = @intCast(u32, buf.len);
        const rc = raw.SDL_Vulkan_GetInstanceExtensions(window, &count, buf.ptr);
        if (rc == 0) return error.SDL_ERROR;

        var buf = try allocator.alloc([*:0]const u8, count);
        errdefer allocator.free(buf);

        const rc = raw.SDL_Vulkan_GetInstanceExtensions(window, &count, buf.ptr);
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

pub const TimerID = extern enum (c_int) { invalid = 0, _ };
pub const TimerCallback = fn(interval: u32, param: ?*c_void) callconv(CC) u32;

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


pub const InitFlags = packed struct {
    timer: bool align(4) = false,
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

    pub fn fromInt(int: InitFlagsInt) InitFlags {
        return @bitCast(InitFlags, int);
    }
    pub fn toInt(self: InitFlags) InitFlagsInt {
        return @bitCast(InitFlagsInt, self);
    }

    comptime {
        if (@alignOf(InitFlags) != @alignOf(InitFlagsInt))
            @compileError("InitFlags must be 4 byte aligned");
        if (@sizeOf(InitFlags) != @sizeOf(InitFlagsInt))
            @compileError("InitFlags must be 4 bytes long");
        if (@bitSizeOf(InitFlags) != @bitSizeOf(InitFlagsInt))
            @compileError("InitFlags must be 32 bits long");
    }
};
pub const InitFlagsInt = u32;

pub fn Init(flags: InitFlags) !void {
    const rc = raw.SDL_Init(flags.toInt());
    if (rc < 0) return error.SDL_ERROR;
}
pub const Quit = raw.SDL_Quit;

pub const raw = struct {
    // --------------------------- SDL.h --------------------------
    pub extern fn SDL_Init(flags: InitFlagsInt) callconv(CC) c_int;
    pub extern fn SDL_InitSubSystem(flags: InitFlagsInt) callconv(CC) c_int;
    pub extern fn SDL_QuitSubSystem(flags: InitFlagsInt) callconv(CC) void;
    pub extern fn SDL_WasInit(flags: InitFlagsInt) callconv(CC) InitFlagsInt;
    pub extern fn SDL_Quit() callconv(CC) void;

    // --------------------------- SDL_error.h --------------------------
    pub extern fn SDL_SetError(fmt: [*:0]const u8, ...) callconv(CC) c_int;
    pub extern fn SDL_GetError() callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_GetErrorMsg(errstr: [*]u8, maxlen: u32) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_ClearError() callconv(CC) void;

    // --------------------------- SDL_rwops.h --------------------------
    pub extern fn SDL_RWFromFile(file: ?[*:0]const u8, mode: ?[*:0]const u8) callconv(CC) ?*RWops;
    pub extern fn SDL_RWFromFP(fp: ?*c_void, autoclose: IntBool) callconv(CC) ?*RWops;
    pub extern fn SDL_RWFromMem(mem: ?*c_void, size: i32) callconv(CC) ?*RWops;
    pub extern fn SDL_RWFromConstMem(mem: ?*const c_void, size: i32) callconv(CC) ?*RWops;
    pub extern fn SDL_AllocRW() callconv(CC) ?*RWops;
    pub extern fn SDL_FreeRW(area: *RWops) callconv(CC) void;
    pub extern fn SDL_RWsize(context: *RWops) callconv(CC) i64;
    pub extern fn SDL_RWseek(context: *RWops, offset: i64, whence: RWops.Whence) callconv(CC) i64;
    pub extern fn SDL_RWtell(context: *RWops) callconv(CC) i64;
    pub extern fn SDL_RWread(context: *RWops, ptr: ?*c_void, size: usize, maxnum: usize) callconv(CC) usize;
    pub extern fn SDL_RWwrite(context: *RWops, ptr: ?*c_void, size: usize, num: usize) callconv(CC) usize;
    pub extern fn SDL_RWclose(context: *RWops) callconv(CC) i32;
    pub extern fn SDL_LoadFile_RW(src: *RWops, datasize: ?*usize, freesrc: i32) callconv(CC) ?*c_void;
    pub extern fn SDL_LoadFile(file: ?[*:0]const u8, datasize: ?*usize) callconv(CC) ?*c_void;

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

    // --------------------------- SDL_audio.h --------------------------
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
        return SDL_LoadWAV_RW(SDL_RWFromFile(file, "rb").?, 1, spec, audio_buf, audio_len);
    }
    pub extern fn SDL_FreeWAV(audio_buf: ?[*]u8) callconv(CC) void;

    pub extern fn SDL_BuildAudioCVT(
        cvt: *audio.CVT,
        src_format: audio.FormatInt,
        src_channels: u8,
        src_rate: i32,
        dst_format: audio.FormatInt,
        dst_channels: u8,
        dst_rate: i32,
    ) callconv(CC) i32;
    pub extern fn SDL_ConvertAudio(cvt: *audio.CVT) callconv(CC) i32;

    pub extern fn SDL_NewAudioStream(
        src_format: audio.FormatInt,
        src_channels: u8,
        src_rate: i32,
        dst_format: audio.FormatInt,
        dst_channels: u8,
        dst_rate: i32,
    ) callconv(CC) ?*audio.Stream;
    pub extern fn SDL_AudioStreamPut(stream: *audio.Stream, buf: ?*c_void, len: i32) callconv(CC) i32;
    pub extern fn SDL_AudioStreamGet(stream: *audio.Stream, buf: ?*c_void, len: i32) callconv(CC) i32;
    pub extern fn SDL_AudioStreamAvailable(stream: *audio.Stream) callconv(CC) i32;
    pub extern fn SDL_AudioStreamFlush(stream: *audio.Stream) callconv(CC) i32;
    pub extern fn SDL_AudioStreamClear(stream: *audio.Stream) callconv(CC) void;
    pub extern fn SDL_FreeAudioStream(stream: *audio.Stream) callconv(CC) void;

    pub extern fn SDL_MixAudio(dst: [*]u8, src: [*]const u8, len: u32, volume: c_int) callconv(CC) void;
    pub extern fn SDL_MixAudioFormat(dst: [*]u8, src: [*]const u8, format: audio.FormatInt, len: u32, volume: c_int) callconv(CC) void;

    pub extern fn SDL_QueueAudio(device: audio.DeviceID, data: ?*c_void, len: u32) callconv(CC) c_int;
    pub extern fn SDL_DequeueAudio(device: audio.DeviceID, data: ?*c_void, len: u32) callconv(CC) c_int;
    pub extern fn SDL_GetQueuedAudioSize(dev: audio.DeviceID) callconv(CC) u32;
    pub extern fn SDL_ClearQueuedAudio(dev: audio.DeviceID) callconv(CC) void;
    pub extern fn SDL_LockAudio() callconv(CC) void;
    pub extern fn SDL_LockAudioDevice(dev: audio.DeviceID) callconv(CC) void;
    pub extern fn SDL_UnlockAudio() callconv(CC) void;
    pub extern fn SDL_UnlockAudioDevice(dev: audio.DeviceID) callconv(CC) void;
    pub extern fn SDL_CloseAudio() callconv(CC) void;
    pub extern fn SDL_CloseAudioDevice(dev: audio.DeviceID) callconv(CC) void;

    // --------------------------- SDL_events.h --------------------------
    pub extern fn SDL_PumpEvents() callconv(CC) void;
    pub extern fn SDL_PeepEvents(events: [*]Event, numevents: i32, action: Event.Action, minType: Event.Type, maxType: Event.Type) callconv(CC) i32;
    pub extern fn SDL_HasEvent(@"type": Event.Type) callconv(CC) IntBool;
    pub extern fn SDL_HasEvents(minType: Event.Type, maxType: Event.Type) callconv(CC) IntBool;
    pub extern fn SDL_FlushEvent(@"type": Event.Type) callconv(CC) void;
    pub extern fn SDL_FlushEvents(minType: Event.Type, maxType: Event.Type) callconv(CC) void;
    pub extern fn SDL_PollEvent(event: *Event) callconv(CC) IntBool;
    pub extern fn SDL_WaitEvent(event: *Event) callconv(CC) IntBool;
    pub extern fn SDL_WaitEventTimeout(event: *Event, timeout: i32) callconv(CC) IntBool;
    pub extern fn SDL_PushEvent(event: *Event) callconv(CC) IntBool;

    pub extern fn SDL_SetEventFilter(filter: ?Event.Filter, userdata: ?*c_void) callconv(CC) void;
    pub extern fn SDL_GetEventFilter(filter: *?Event.Filter, userdata: *?*c_void) callconv(CC) IntBool;
    pub extern fn SDL_AddEventWatch(filter: Event.Filter, userdata: ?*c_void) callconv(CC) void;
    pub extern fn SDL_DelEventWatch(filter: Event.Filter, userdata: ?*c_void) callconv(CC) void;
    pub extern fn SDL_FilterEvents(filter: Event.Filter, userdata: ?*c_void) callconv(CC) void;

    pub extern fn SDL_EventState(@"type": Event.Type, state: Event.State) callconv(CC) u8;
    pub fn SDL_GetEventState(@"type": Event.Type) callconv(.Inline) Event.State {
        return @intToEnum(Event.State, @intCast(c_int, SDL_EventState(@"type", .query)));
    }
    pub extern fn SDL_RegisterEvents(numevents: i32) callconv(CC) u32;

    // --------------------------- SDL_gesture.h --------------------------
    pub extern fn SDL_RecordGesture(touchId: TouchID) callconv(CC) i32;
    pub extern fn SDL_SaveAllDollarTemplates(dst: *RWops) callconv(CC) i32;
    pub extern fn SDL_SaveDollarTemplate(gestureId: GestureID, dst: *RWops) callconv(CC) i32;
    pub extern fn SDL_LoadDollarTemplates(touchId: TouchID, src: *RWops) callconv(CC) i32;

    // --------------------------- SDL_joystick.h --------------------------
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
    pub extern fn SDL_JoystickAttachVirtual(@"type": SDL_JoystickType, naxes: i32, nbuttons: i32, nhats: i32) callconv(CC) i32;
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

    // --------------------------- SDL_pixels.h --------------------------
    pub extern fn SDL_GetPixelFormatName(format: PixelFormatEnum.Int) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_PixelFormatEnumToMasks(format: PixelFormatEnum.Int, bpp: *i32, rMask: *u32, gMask: *u32, bMask: *u32, aMask: *u32) callconv(CC) IntBool;
    pub extern fn SDL_MasksToPixelFormatEnum(bpp: i32, rMask: u32, gMask: u32, bMask: u32, aMask: u32) callconv(CC) PixelFormatEnum.Int;
    pub extern fn SDL_AllocFormat(pixel_format: PixelFormatEnum.Int) callconv(CC) ?*const PixelFormat;
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

    // --------------------------- SDL_rect.h --------------------------
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

    // --------------------------- SDL_timer.h --------------------------
    pub extern fn SDL_GetTicks() callconv(CC) u32;
    pub fn SDL_TICKS_PASSED(a: u32, b: u32) callconv(.Inline) bool {
        return @bitCast(i32, b) - @bitCast(i32, a) <= 0; 
    }
    pub extern fn SDL_GetPerformanceCounter() callconv(CC) u64;
    pub extern fn SDL_GetPerformanceFrequency() callconv(CC) u64;
    pub extern fn SDL_Delay(ms: u32) callconv(CC) void;
    pub extern fn SDL_AddTimer(interval: u32, callback: TimerCallback, param: ?*c_void) callconv(CC) TimerID;
    pub extern fn SDL_RemoveTimer(id: TimerID) IntBool;

    // --------------------------- SDL_touch.h --------------------------
    pub extern fn SDL_GetNumTouchDevices() callconv(CC) i32;
    pub extern fn SDL_GetTouchDevice(index: i32) callconv(CC) TouchID;
    pub extern fn SDL_GetTouchDeviceType(touchID: TouchID) callconv(CC) TouchDeviceType;
    pub extern fn SDL_GetNumTouchFingers(touchID: TouchID) callconv(CC) i32;
    pub extern fn SDL_GetTouchFinger(touchID: TouchID, index: i32) callconv(CC) ?*Finger;

    // --------------------------- SDL_video.h --------------------------
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
    pub extern fn SDL_GetDisplayOrientation(displayIndex: i32) callconv(CC) DisplayOrientation.Int;
    pub extern fn SDL_GetNumDisplayModes(displayIndex: i32) callconv(CC) i32;
    pub extern fn SDL_GetDisplayMode(displayIndex: i32, modeIndex: i32, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetDesktopDisplayMode(displayIndex: i32, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetCurrentDisplayMode(displayIndex: i32, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetClosestDisplayMode(displayIndex: i32, mode: *const video.DisplayMode, closest: *video.DisplayMode) callconv(CC) ?*video.DisplayMode;
    
    pub extern fn SDL_GetWindowDisplayIndex(window: *Window) callconv(CC) c_int;
    pub extern fn SDL_SetWindowDisplayMode(window: *Window, mode: *const video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetWindowDisplayMode(window: *Window, mode: *video.DisplayMode) callconv(CC) c_int;
    pub extern fn SDL_GetWindowPixelFormat(window: *Window) callconv(CC) PixelFormatEnum.Int;
    pub extern fn SDL_CreateWindow(title: ?[*:0]const u8, x: i32, y: i32, w: i32, h: i32, flags: Window.Flags.Int) callconv(CC) ?*Window;
    pub extern fn SDL_CreateWindowFrom(data: ?*c_void) callconv(CC) ?*Window;
    pub extern fn SDL_GetWindowID(window: *Window) callconv(CC) u32;
    pub extern fn SDL_GetWindowFromID(id: u32) callconv(CC) ?*Window;
    pub extern fn SDL_GetWindowFlags(window: *Window) callconv(CC) Window.Flags.Int;
    pub extern fn SDL_SetWindowTitle(window: *Window, title: ?[*:0]const u8) callconv(CC) void;
    pub extern fn SDL_GetWindowTitle(window: *Window) callconv(CC) ?[*:0]const u8;
    pub extern fn SDL_SetWindowIcon(window: *Window, icon: *Surface) callconv(CC) void;
    pub extern fn SDL_SetWindowData(window: *Window, name: [*:0]const u8, userdata: ?*c_void) callconv(CC) ?*c_void;
    pub extern fn SDL_GetWindowData(window: *Window, name: [*:0]const u8) callconv(CC) ?*c_void;
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
    pub extern fn SDL_SetWindowHitTest(window: *Window, callback: ?window.HitTest, callback_data: ?*c_void) callconv(CC) c_int;
    pub extern fn SDL_DestroyWindow(window: *Window) callconv(CC) void;

    pub extern fn SDL_IsScreenSaverEnabled() callconv(CC) IntBool;
    pub extern fn SDL_EnableScreenSaver() callconv(CC) void;
    pub extern fn SDL_DisableScreenSaver() callconv(CC) void;

    pub extern fn SDL_GL_LoadLibrary(path: ?[*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_GL_GetProcAddress(proc: [*:0]const u8) callconv(CC) ?*c_void;
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
    pub extern fn SDL_Vulkan_LoadLibrary(path: ?[*:0]const u8) callconv(CC) c_int;
    pub extern fn SDL_Vulkan_GetVkGetInstanceProcAddr() callconv(CC) ?*c_void;
    pub extern fn SDL_Vulkan_UnloadLibrary() callconv(CC) void;
    pub extern fn SDL_Vulkan_GetInstanceExtensions(window: *Window, pCount: *u32, pNames: ?[*][*:0]const u8) callconv(CC) IntBool;
    pub extern fn SDL_Vulkan_CreateSurface(window: *Window, instance: vk.Instance, surface: *vk.SurfaceKHR) callconv(CC) IntBool;
    pub extern fn SDL_Vulkan_GetDrawableSize(window: *Window, w: *i32, h: *i32) callconv(CC) void;
};
