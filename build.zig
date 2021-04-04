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

    exe.linkLibC();

    // Link platform object files
    if (target.isWindows()) {
        exe.linkSystemLibrary("lib/win_x64/vulkan-1");
        exe.linkSystemLibrary("lib/win_x64/SDL2");
        // Windows DLLs we need
        exe.linkSystemLibrary("Advapi32");
        exe.linkSystemLibrary("Gdi32");
        exe.linkSystemLibrary("Imm32");
        exe.linkSystemLibrary("Ole32");
        exe.linkSystemLibrary("OleAut32");
        exe.linkSystemLibrary("SetupAPI");
        exe.linkSystemLibrary("Shell32");
        exe.linkSystemLibrary("User32");
        exe.linkSystemLibrary("Version"); // Api-ms-win-core-version-l1-1-0.dll
        exe.linkSystemLibrary("Winmm");
    } else {
        return error.TodoLinkLibrariesForNonWindowsPlatforms;
    }

    // Link VMA source directly
    exe.addCSourceFile("c_src/vma.cpp", getVmaArgs(mode));
    exe.addIncludeDir("c_src/vma");

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

fn getVmaArgs(mode: std.builtin.Mode) []const []const u8 {
    const commonArgs = &[_][]const u8 { };
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
