const std = @import("std");
const vk = @import("vk");
const vma = @import("vma");
const sdl = @import("sdl");
const simd = @import("simd.zig");

pub const assert = std.debug.assert;

pub const GpuBuffer = struct {
    buffer: vk.Buffer,
    alloc: vma.Allocation,

    pub fn init(
        vma_alloc: vma.Allocator,
        size: vk.DeviceSize,
        mem_usage: vma.MemoryUsage,
        buf_usage: vk.BufferUsageFlags,
    ) !GpuBuffer {
        const results = try vma_alloc.createBuffer(
            .{ .size = size, .usage = buf_usage, .sharingMode = .EXCLUSIVE },
            .{ .usage = mem_usage },
        );
        return GpuBuffer{
            .buffer =  results.buffer,
            .alloc = results.allocation,
        };
    }

    pub fn deinit(self: GpuBuffer, vma_alloc: vma.Allocator) void {
        vma_alloc.destroyBuffer(self.buffer, self.alloc);
    }
};

pub const GpuMesh = struct {
    uploaded: vk.Fence,
    idx_count: usize,
    idx_type: vk.IndexType,
    size: usize,
    host: GpuBuffer,
    gpu: GpuBuffer,

    pub fn init(device: vk.Device, vma_alloc: vma.Allocator, src: CpuMesh) !GpuMesh {
        const total_size = @intCast(usize, src.index_size + src.geom_size);

        const host_buffer = try GpuBuffer.init(vma_alloc, total_size, .cpuToGpu, .{ .transferSrc = true });
        errdefer host_buffer.deinit(vma_alloc);

        const device_buffer = try GpuBuffer.init(vma_alloc, total_size, .gpuOnly, .{
            .vertexBuffer = true, .indexBuffer = true, .transferDst = true,
        });
        errdefer device_buffer.deinit(vma_alloc);

        const fence = try vk.CreateFence(device, .{}, null);
        errdefer vk.DestroyFence(device, fence, null);

        // Copy the data into the cpu buffer
        {
            const data = try vma_alloc.mapMemory(host_buffer.alloc, u8);
            defer vma_alloc.unmapMemory(host_buffer.alloc);

            var offset: usize = 0;
            // Copy Indices
            var size = src.index_size;
            @memcpy(data + offset, @ptrCast([*]const u8, src.indices), size);
            offset += size;
            // Copy Positions
            size = @sizeOf(simd.Float3) * src.vertex_count;
            @memcpy(data + offset, @ptrCast([*]const u8, src.positions), size);
            offset += size;
            // Copy Colors
            @memcpy(data + offset, @ptrCast([*]const u8, src.colors), size);
            offset += size;
            // Copy Normals
            @memcpy(data + offset, @ptrCast([*]const u8, src.normals), size);
            offset += size;

            assert(offset == total_size);
        }

        return GpuMesh{
            .uploaded = fence,
            .idx_count = src.index_count,
            .idx_type = .UINT16,
            .size = total_size,
            .host = host_buffer,
            .gpu = device_buffer,
        };
    }

    pub fn deinit(self: GpuMesh, device: vk.Device, vma_alloc: vma.Allocator) void {
        self.host.deinit(vma_alloc);
        self.gpu.deinit(vma_alloc);
        vk.DestroyFence(device, self.uploaded, null);
    }
};

pub const CpuMesh = struct {
    index_size: u64,
    geom_size: u64,
    index_count: u32,
    vertex_count: u32,
    indices: [*]const u16,
    positions: [*]const simd.Float3,
    colors: [*]const simd.Float3,
    normals: [*]const simd.Float3,
};

pub const PUSH_CONSTANT_BYTES = 256;

pub const PushConstants = extern struct {
    time: simd.Float4,
    resolution: simd.Float2,
    mvp: simd.Float4x4,
    m: simd.Float4x4,
};
comptime {
    if (@sizeOf(PushConstants) > PUSH_CONSTANT_BYTES)
        @compileError("Too Many Push Constants");
}

/// Takes a pointer type like *T, *const T, *align(4)T, etc,
/// returns the pointer type *[1]T, *const [1]T, *align(4) [1]T, etc.
pub fn ArrayPtr(comptime ptrType: type) type {
    comptime {
        // Check that the input is of type *T
        var info = @typeInfo(ptrType);
        assert(info == .Pointer);
        assert(info.Pointer.size == .One);
        assert(info.Pointer.sentinel == null);

        // Create the new value type, [1]T
        const arrayInfo = std.builtin.TypeInfo{
            .Array = .{
                .len = 1,
                .child = info.Pointer.child,
                .sentinel = @as(?info.Pointer.child, null),
            },
        };

        // Patch the type to be *[1]T, preserving other modifiers
        const singleArrayType = @Type(arrayInfo);
        info.Pointer.child = singleArrayType;
        // also need to change the type of the sentinel
        // we checked that this is null above so no work needs to be done here.
        info.Pointer.sentinel = @as(?singleArrayType, null);
        return @Type(info);
    }
}

pub fn arrayPtr(ptr: anytype) callconv(.Inline) ArrayPtr(@TypeOf(ptr)) {
    return ptr;
}
