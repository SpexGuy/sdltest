const std = @import("std");
const Builder = std.build.Builder;
const vma_config = @import("include/vma_config.zig");

pub fn build(b: *Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Option to override whether shaders are built in debug mode.  Defaults to
    // (mode == .Debug).
    const debug_shaders = b.option(bool, "debug-shaders", "Set whether shaders are compiled in debug mode")
        orelse (mode == .Debug);
    const fractal = addShaderSteps(b, "fractal", debug_shaders);
    const mesh = addShaderSteps(b, "mesh", debug_shaders);

    const exe = b.addExecutable("sdltest", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.step.dependOn(fractal);
    exe.step.dependOn(mesh);

    try linkSDL(b, exe, target, mode);

    // Link platform object files
    if (target.isWindows()) {
        exe.linkSystemLibrary("lib/win_x64/vulkan-1");
    } else {
        return error.TodoLinkLibrariesForNonWindowsPlatforms;
    }

    // Link VMA source directly
    exe.addCSourceFile("c_src/vma.cpp", getVmaArgs(mode));
    exe.addIncludeDir("c_src/vma");
    if (target.getAbi() != .msvc) {
        exe.linkSystemLibrary("c++");
    }

    const vk: std.build.Pkg = .{
        .name = "vk",
        .path = "include/vulkan_core.zig",
    };
    const sdl: std.build.Pkg = .{
        .name = "sdl",
        .path = "include/sdl.zig",
        .dependencies = &.{ vk },
    };
    const vma: std.build.Pkg = .{
        .name = "vma",
        .path = "include/vma.zig",
        .dependencies = &.{ vk },
    };

    exe.addPackage(vk);
    exe.addPackage(sdl);
    exe.addPackage(vma);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addShaderSteps(b: *Builder, name: []const u8, debug: bool) *std.build.Step {
    const hlsl = b.fmt("shaders/{s}.hlsl", .{name});
    const vert_out = b.fmt("src/shader_data/{s}_vert.spv", .{name});
    const frag_out = b.fmt("src/shader_data/{s}_frag.spv", .{name});
    const vert = DxcCompileShaderStep.createVert(b, hlsl, vert_out);
    const frag = DxcCompileShaderStep.createFrag(b, hlsl, frag_out);

    if (debug) {
        vert.optimization_level = 0;
        vert.enable_debug_info = true;
        vert.embed_debug_info = true;

        frag.optimization_level = 0;
        frag.enable_debug_info = true;
        frag.embed_debug_info = true;
    }

    const step = b.step(name, b.fmt("Build shaders from {s}", .{hlsl}));
    step.dependOn(&vert.step);
    step.dependOn(&frag.step);

    return step;
}

fn linkSDL(b: *Builder, step: *std.build.LibExeObjStep, target: std.zig.CrossTarget, mode: std.builtin.Mode) !void {
    step.addIncludeDir("sdl/include");
    step.addIncludeDir("sdl/src/video/khronos");

    var c_args = std.ArrayList([]const u8).init(b.allocator);
    c_args.append("-DHAVE_LIBC") catch unreachable;
    step.linkLibC();

    if (mode != .ReleaseFast) {
        c_args.append("-DNDEBUG") catch unreachable;
    } else {
        c_args.append("-D_DEBUG") catch unreachable;
    }

    if (target.isWindows()) {
        c_args.append("-D_WINDOWS") catch unreachable;
    }

    // TODO: There's probably a much better way to do this, building a static
    // data structure and pulling dirs out of it.

    var source_files = std.ArrayList([]const u8).init(b.allocator);
    var source_dirs = std.ArrayList([]const u8).init(b.allocator);
    source_dirs.appendSlice(&.{
        "sdl/src",
        "sdl/src/atomic",
        "sdl/src/audio",
        "sdl/src/cpuinfo",
        "sdl/src/dynapi",
        "sdl/src/events",
        "sdl/src/file",
        "sdl/src/haptic",
        "sdl/src/libm",
        "sdl/src/locale",
        "sdl/src/misc",
        "sdl/src/power",
        "sdl/src/render",
        "sdl/src/sensor",
        "sdl/src/stdlib",
        "sdl/src/thread",
        "sdl/src/timer",
        "sdl/src/video",
        "sdl/src/video/yuv2rgb",
    }) catch unreachable;
    source_dirs.appendSlice(try collectChildDirectories(b, "sdl/src/render")) catch unreachable;

    // TODO: Detect android, can't do this from target alone
    const android = false;
    const have_audio = true;
    const have_filesystem = true;
    const have_haptic = true;
    const have_hidapi = true;
    const have_joystick = true; // missing system include windows.gaming.input.h
    const have_loadso = true;
    const have_misc = true;
    const have_power = true;
    const have_locale = true;
    const have_timers = true;
    const have_sensor = true;
    const have_threads = true;
    const have_video = true;

    if (have_joystick) {
        source_dirs.append("sdl/src/joystick") catch unreachable;
        const have_virtual_joystick = true;
        if (have_virtual_joystick) {
            source_dirs.append("sdl/src/joystick/virtual") catch unreachable;
        }
        if (have_hidapi) {
            source_dirs.append("sdl/src/joystick/hidapi") catch unreachable;
        }
    }

    if (have_audio) {
        const dummy_audio = true;
        const disk_audio = true;
        if (dummy_audio) {
            source_dirs.append("sdl/src/audio/dummy") catch unreachable;
        }
        if (disk_audio) {
            source_dirs.append("sdl/src/audio/disk") catch unreachable;
        }
    }

    if (have_video) {
        const dummy_video = true;
        const offscreen_video = false;
        if (dummy_video) {
            source_dirs.append("sdl/src/video/dummy") catch unreachable;
        }
        if (offscreen_video) {
            source_dirs.append("sdl/src/video/offscreen") catch unreachable;
        }
    }

    if (android) {
        // TODO: CMakeLists.txt line 964 include ndk sources also.
        source_dirs.append("sdl/src/core/android") catch unreachable;
        source_dirs.append("sdl/src/misc/android") catch unreachable;
        if (have_audio) source_dirs.append("sdl/src/audio/android") catch unreachable;
        if (have_filesystem) source_dirs.append("sdl/src/filesystem/android") catch unreachable;
        if (have_haptic) source_dirs.append("sdl/src/haptic/android") catch unreachable;
        if (have_joystick) source_dirs.append("sdl/src/joystick/android") catch unreachable;
        if (have_loadso) source_dirs.append("sdl/src/loadso/dlopen") catch unreachable;
        if (have_power) source_dirs.append("sdl/src/power/android") catch unreachable;
        if (have_locale) source_dirs.append("sdl/src/locale/android") catch unreachable;
        if (have_timers) source_dirs.append("sdl/src/timer/unix") catch unreachable;
        if (have_sensor) source_dirs.append("sdl/src/sensor/android") catch unreachable;
        if (have_video) {
            source_dirs.append("sdl/src/video/android") catch unreachable;
            c_args.append("-DGL_GLEXT_PROTOTYPES") catch unreachable;
            // TODO: more stuff here
        }
    }

    // TODO: Linux

    if (target.isWindows()) {
        source_dirs.appendSlice(&.{
            "sdl/src/core/windows",
            "sdl/src/misc/windows",
        }) catch unreachable;

        // TODO: windows store
        // TODO: directx

        if (have_audio) {
            const have_dsound = true;
            const have_wasapi = true;

            source_dirs.append("sdl/src/audio/winmm") catch unreachable;
            if (have_dsound) {
                source_dirs.append("sdl/src/audio/directsound") catch unreachable;
            }
            if (have_wasapi) {
                source_dirs.append("sdl/src/audio/wasapi") catch unreachable;
            }
        }

        if (have_video) {
            if (!have_loadso) {
                std.debug.print("{s}", .{"Error: SDL video requires loadso on windows.\n"});
                std.os.exit(-1);
            }
            // TODO: Windows store
            source_dirs.append("sdl/src/video/windows") catch unreachable;
            // TODO: D3D
        }

        if (have_threads) {
            source_files.appendSlice(&.{
                "sdl/src/thread/windows/SDL_sysmutex.c",
                "sdl/src/thread/windows/SDL_syssem.c",
                "sdl/src/thread/windows/SDL_systhread.c",
                "sdl/src/thread/windows/SDL_systls.c",
                "sdl/src/thread/generic/SDL_syscond.c",
            }) catch unreachable;
        }

        if (have_sensor) {
            source_dirs.append("sdl/src/sensor/windows") catch unreachable;
        }

        if (have_power) {
            // TODO: windows store
            source_files.append("sdl/src/power/windows/SDL_syspower.c") catch unreachable;
        }

        if (have_locale) {
            source_dirs.append("sdl/src/locale/windows") catch unreachable;
        }

        if (have_filesystem) {
            // TODO: windows store
            source_dirs.append("sdl/src/filesystem/windows") catch unreachable;
        }

        if (have_timers) {
            source_dirs.append("sdl/src/timer/windows") catch unreachable;
        }

        if (have_loadso) {
            source_dirs.append("sdl/src/loadso/windows") catch unreachable;
        }

        if (have_video) {
            // TODO: This just sets vars in cmake that aren't used?
            // Also it's redundant with the check above.
        }

        if (have_joystick) {
            if (have_hidapi) {
                source_files.append("sdl/src/hidapi/windows/hid.c") catch unreachable;
            }
            // TODO: lots of options here
            source_dirs.append("sdl/src/joystick/windows") catch unreachable;
            if (have_haptic) {
                // TODO
                source_dirs.append("sdl/src/haptic/windows") catch unreachable;
            }
        }

        // Windows DLLs we need
        // TODO: not needed for windows store
        step.linkSystemLibrary("Advapi32");
        step.linkSystemLibrary("Gdi32");
        step.linkSystemLibrary("Imm32");
        step.linkSystemLibrary("Ole32");
        step.linkSystemLibrary("OleAut32");
        step.linkSystemLibrary("SetupAPI");
        step.linkSystemLibrary("Shell32");
        step.linkSystemLibrary("User32");
        step.linkSystemLibrary("Version"); // Api-ms-win-core-version-l1-1-0.dll
        step.linkSystemLibrary("Winmm");
    }

    // TODO: apple
    // TODO: haiku
    // TODO: riscos

    // dummy files
    if (!have_joystick) source_dirs.append("sdl/src/joystick/dummy") catch unreachable;
    if (!have_haptic) source_dirs.append("sdl/src/haptic/dummy") catch unreachable;
    if (!have_sensor) source_dirs.append("sdl/src/sensor/dummy") catch unreachable;
    if (!have_loadso) source_dirs.append("sdl/src/loadso/dummy") catch unreachable;
    if (!have_filesystem) source_dirs.append("sdl/src/filesystem/dummy") catch unreachable;
    if (!have_locale) source_dirs.append("sdl/src/locale/dummy") catch unreachable;
    if (!have_misc) source_dirs.append("sdl/src/misc/dummy") catch unreachable;
    if (!have_threads) source_dirs.append("sdl/src/thread/generic") catch unreachable;
    if (!have_timers) source_dirs.append("sdl/src/timer/dummy") catch unreachable;

    for (source_dirs.items) |dir| {
        source_files.appendSlice(try collectSources(b, dir, ".c")) catch unreachable;
    }

    step.addCSourceFiles(source_files.items, c_args.items);
}

fn collectSources(b: *Builder, path: []const u8, extension: []const u8) ![]const []const u8 {
    var sources = std.ArrayList([]const u8).init(b.allocator);
    const dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();
    while (try it.next()) |child| {
        if (child.kind == .File) {
            const ext = std.fs.path.extension(child.name);
            if (std.ascii.eqlIgnoreCase(ext, extension)) {
                const full_path = std.fs.path.join(b.allocator, &.{path, child.name}) catch unreachable;
                sources.append(full_path) catch unreachable;
            }
        }
    }
    return sources.toOwnedSlice();
}

fn collectChildDirectories(b: *Builder, path: []const u8) ![]const []const u8 {
    var dirs = std.ArrayList([]const u8).init(b.allocator);
    const dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();
    while (try it.next()) |child| {
        if (child.kind == .Directory) {
            const full_path = std.fs.path.join(b.allocator, &.{path, child.name}) catch unreachable;
            dirs.append(full_path) catch unreachable;
        }
    }
    return dirs.toOwnedSlice();
}

fn getVmaArgs(mode: std.builtin.Mode) []const []const u8 {
    const commonArgs = &[_][]const u8 { "-std=c++14" };
    const releaseArgs = &[_][]const u8 { } ++ commonArgs ++ comptime getVmaConfigArgs(vma_config.releaseConfig);
    const debugArgs = &[_][]const u8 { } ++ commonArgs ++ comptime getVmaConfigArgs(vma_config.debugConfig);
    const args = if (mode == .Debug) debugArgs else releaseArgs;
    return args;
}

fn getVmaConfigArgs(comptime config: vma_config.Config) []const []const u8 {
    comptime {
        @setEvalBranchQuota(100000);
        var args: []const []const u8 = &[_][]const u8 {
            std.fmt.comptimePrint("-DVMA_VULKAN_VERSION={}", .{ config.vulkanVersion }),
            std.fmt.comptimePrint("-DVMA_DEDICATED_ALLOCATION={}", .{ @boolToInt(config.dedicatedAllocation)}),
            std.fmt.comptimePrint("-DVMA_BIND_MEMORY2={}", .{ @boolToInt(config.bindMemory2)}),
            std.fmt.comptimePrint("-DVMA_MEMORY_BUDGET={}", .{ @boolToInt(config.memoryBudget)}),
            std.fmt.comptimePrint("-DVMA_STATIC_VULKAN_FUNCTIONS={}", .{ @boolToInt(config.staticVulkanFunctions)}),
            std.fmt.comptimePrint("-DVMA_STATS_STRING_ENABLED={}", .{ @boolToInt(config.statsStringEnabled)}),
        };
        if (config.debugInitializeAllocations) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_DEBUG_INITIALIZE_ALLOCATIONS={}",
                .{ @boolToInt(value) },
            ) };
        }
        if (config.debugMargin) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_DEBUG_MARGIN={}",
                .{ value },
            ) };
        }
        if (config.debugDetectCorruption) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_DEBUG_DETECT_CORRUPTION={}",
                .{ @boolToInt(value) },
            ) };
        }
        if (config.recordingEnabled) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_RECORDING_ENABLED={}",
                .{ @boolToInt(value) },
            ) };
        }
        if (config.debugMinBufferImageGranularity) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_DEBUG_MIN_BUFFER_IMAGE_GRANULARITY={}",
                .{ value },
            ) };
        }
        if (config.debugGlobalMutex) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_DEBUG_GLOBAL_MUTEX={}",
                .{ @boolToInt(value) },
            ) };
        }
        if (config.useStlContainers) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_USE_STL_CONTAINERS={}",
                .{ @boolToInt(value) },
            ) };
        }
        if (config.useStlSharedMutex) |value| {
            args = args ++ &[_][]const u8 { std.fmt.comptimePrint(
                "-DVMA_USE_STL_SHARED_MUTEX={}",
                .{ @boolToInt(value) },
            ) };
        }

        return args;
    }
}

const DxcCompileShaderStep = struct {
    step: std.build.Step,
    builder: *Builder,
    hlsl_file: []const u8,
    out_file: []const u8,
    entry_point: []const u8,
    profile: Profile = .unspecified,
    optimization_level: u2 = 3,
    enable_debug_info: bool = false,
    embed_debug_info: bool = false,
    include_reflection: bool = true,

    pub fn createVert(b: *Builder, hlsl_file: []const u8, out_file: []const u8) *DxcCompileShaderStep {
        const self = b.allocator.create(@This()) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.Custom, hlsl_file, b.allocator, make),
            .builder = b,
            .hlsl_file = b.dupePath(hlsl_file),
            .out_file = b.dupePath(out_file),
            .entry_point = "vert",
            .profile = .vs_6_0,
        };
        return self;
    }

    pub fn createFrag(b: *Builder, hlsl_file: []const u8, out_file: []const u8) *DxcCompileShaderStep {
        const self = b.allocator.create(@This()) catch unreachable;
        self.* = .{
            .step = std.build.Step.init(.Custom, hlsl_file, b.allocator, make),
            .builder = b,
            .hlsl_file = b.dupePath(hlsl_file),
            .out_file = b.dupePath(out_file),
            .entry_point = "frag",
            .profile = .ps_6_0,
        };
        return self;
    }

    pub fn make(step: *std.build.Step) anyerror!void {
        const self = @fieldParentPtr(@This(), "step", step);
        const b = self.builder;

        // dxc doesn't do mkdirs so we need to.
        if (std.fs.path.dirname(self.out_file)) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        var args = std.ArrayList([]const u8).init(b.allocator);
        defer args.deinit();

        args.append("dxc") catch unreachable;

        if (self.profile != .none) {
            args.append("-T") catch unreachable;
            args.append(@tagName(self.profile)) catch unreachable;
        }

        args.append("-E") catch unreachable;
        args.append(self.entry_point) catch unreachable;

        args.append(b.fmt("-O{d}", .{self.optimization_level})) catch unreachable;

        if (self.enable_debug_info) args.append("-Zi") catch unreachable;
        if (self.embed_debug_info) args.append("-Qembed_debug") catch unreachable;
        if (self.include_reflection) args.append("-fspv-reflect") catch unreachable;

        args.append("-spirv") catch unreachable;

        args.append(self.hlsl_file) catch unreachable;

        args.append("-Fo") catch unreachable;
        args.append(self.out_file) catch unreachable;

        _ = try self.builder.execFromStep(args.items, &self.step);
    }

    pub const Profile = enum {
        none,
        ps_6_0, ps_6_1, ps_6_2, ps_6_3, ps_6_4, ps_6_5, ps_6_6,
        vs_6_0, vs_6_1, vs_6_2, vs_6_3, vs_6_4, vs_6_5, vs_6_6,
        gs_6_0, gs_6_1, gs_6_2, gs_6_3, gs_6_4, gs_6_5, gs_6_6,
        hs_6_0, hs_6_1, hs_6_2, hs_6_3, hs_6_4, hs_6_5, hs_6_6,
        ds_6_0, ds_6_1, ds_6_2, ds_6_3, ds_6_4, ds_6_5, ds_6_6,
        cs_6_0, cs_6_1, cs_6_2, cs_6_3, cs_6_4, cs_6_5, cs_6_6,
        lib_6_1, lib_6_2, lib_6_3, lib_6_4, lib_6_5, lib_6_6,
        ms_6_5, ms_6_6,
        as_6_5, as_6_6,
    };
};
