const builtin = @import("builtin");
const camera = @import("camera.zig");
const cmn = @import("common.zig");
const cube_cpu = @import("cube.zig").cpu_mesh;
const pipelines = @import("pipelines.zig");
const sdl = @import("sdl");
const simd = @import("simd.zig");
const std = @import("std");
const vk = @import("vk");
const vma = @import("vma");
const assert = std.debug.assert;

const arrayPtr = cmn.arrayPtr;

const MAX_LAYER_COUNT = 16;
const MAX_EXT_COUNT = 16;

const FRAME_LATENCY = 3;
const MESH_UPLOAD_QUEUE_SIZE = 16;

const WIDTH = 1600;
const HEIGHT = 900;

const USE_VALIDATION = builtin.mode != .ReleaseFast;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    // exit doesn't play well with defers,
    // so we use an inner function to ensure they run.
    try mainNoExit();
    std.os.exit(0);
}

pub fn mainNoExit() !void {
    const qtr_pi = 0.7853981625;

    var main_cam: camera.Camera = .{
        .transform = .{ .position = .{0, 0, 10} },
        .aspect = @intToFloat(f32, WIDTH) / @intToFloat(f32, HEIGHT),
        .fov = qtr_pi,
        .near = 0.01,
        .far = 100,
    };
    var controller: camera.EditorCameraController = .{ .speed = 10 };

    try sdl.Init(.{ .video = true });
    defer sdl.Quit();


    const centered = sdl.Window.pos_centered;
    const window = try sdl.Window.create("SDL Test", centered, centered, WIDTH, HEIGHT, .{ .vulkan = true });
    defer window.destroy();

    // Create vulkan instance
    var instance = blk: {
        var layers: StackBuffer([*:0]const u8, MAX_LAYER_COUNT) = .{};

        {
            const instance_layer_count = try vk.EnumerateInstanceLayerPropertiesCount();
            if (instance_layer_count > 0) {
                const instance_layers_buf = try allocator.alloc(vk.LayerProperties, instance_layer_count);
                defer allocator.free(instance_layers_buf);
                const instance_layers = (try vk.EnumerateInstanceLayerProperties(instance_layers_buf)).properties;

                if (USE_VALIDATION) {
                    const validation_layer_name = "VK_LAYER_KHRONOS_validation";
                    if (hasLayer(validation_layer_name, instance_layers)) {
                        layers.add(validation_layer_name);
                    } else {
                        std.debug.print("Warning: Validation requested, but layer "++validation_layer_name++" does not exist on this computer.\n", .{});
                        std.debug.print("Validation will not be enabled.\n", .{});
                    }
                }
            }
        }

        var extensions: StackBuffer([*:0]const u8, MAX_EXT_COUNT) = .{};
        extensions.count = (try sdl.vulkan.getInstanceExtensions(window, &extensions.buf)).len;

        // Our shaders require this extension.
        //extensions.add(vk.GOOGLE_HLSL_FUNCTIONALITY1_EXTENSION_NAME);

        if (USE_VALIDATION) {
            extensions.add(vk.EXT_DEBUG_UTILS_EXTENSION_NAME);
        }

        const app_info: vk.ApplicationInfo = .{
            .pApplicationName = "SDL Test",
            .applicationVersion = vk.MAKE_VERSION(0, 0, 1),
            .pEngineName = "SDL Test",
            .engineVersion = vk.MAKE_VERSION(0, 0, 1),
            .apiVersion = vk.API_VERSION_1_1,
        };

        break :blk try vk.CreateInstance(.{
            .pApplicationInfo = &app_info,
            .enabledLayerCount = @intCast(u32, layers.count),
            .ppEnabledLayerNames = &layers.buf,
            .enabledExtensionCount = @intCast(u32, extensions.count),
            .ppEnabledExtensionNames = &extensions.buf,
        }, null);
    };
    defer vk.DestroyInstance(instance, null);

    var d = try Demo.init(window, instance);
    defer d.deinit();

    var cube_transform: simd.Transform = .{};

    var running = true;
    var last_time_ms: f32 = 0;

    run_loop: while (running) {
        // Crunch some numbers
        const time_ms = @intToFloat(f32, sdl.getTicks());
        defer last_time_ms = time_ms;
        const time_seconds = time_ms / 1000.0;
        const delta_time_ms = time_ms - last_time_ms;
        const delta_time_seconds = delta_time_ms / 1000.0;
        const time_ns: f32 = 0;
        const time_us: f32 = 0;

        controller.newFrame();

        // Process events until we have seen them all
        while (sdl.pollEvent()) |e| {
            if (e.type == .QUIT) {
                running = false;
                break :run_loop;
            }
            controller.handleEvent(e);
        }

        // Move the camera
        controller.updateCamera(delta_time_seconds, &main_cam);

        // Spin cube
        cube_transform.rotation[1] += 1.0 * delta_time_seconds;
        const cube_obj_mat = cube_transform.toMatrix();

        const vp = main_cam.viewProjection();
        const cube_mvp = simd.mulmf44(vp, cube_obj_mat);

        // Pass time to shader
        d.push_constants.time = .{time_seconds, time_ms, time_ns, time_us};
        d.push_constants.resolution = .{
            @intToFloat(f32, d.swap_width),
            @intToFloat(f32, d.swap_height),
        };

        d.push_constants.mvp = cube_mvp;
        d.push_constants.m = cube_obj_mat;

        try d.renderFrame();
    }
}

const Demo = struct {
    instance: vk.Instance,

    gpu: vk.PhysicalDevice,
    gpu_props: vk.PhysicalDeviceProperties,
    queue_props: []vk.QueueFamilyProperties,
    gpu_features: vk.PhysicalDeviceFeatures,

    surface: vk.SurfaceKHR,
    graphics_queue_family_index: u32,
    present_queue_family_index: u32,
    separate_present_queue: bool,

    device: vk.Device,
    present_queue: vk.Queue,
    graphics_queue: vk.Queue,
    
    vma_allocator: vma.Allocator,
    
    swapchain_image_format: vk.Format,
    swapchain: vk.SwapchainKHR,
    swapchain_image_count: u32,
    swap_width: u32,
    swap_height: u32,

    render_pass: vk.RenderPass,
    pipeline_cache: vk.PipelineCache,

    pipeline_layout: vk.PipelineLayout,
    fractal_pipeline: vk.Pipeline,
    mesh_pipeline: vk.Pipeline,

    swapchain_images: [FRAME_LATENCY]vk.Image = [_]vk.Image{.Null} ** FRAME_LATENCY,
    swapchain_image_views: [FRAME_LATENCY]vk.ImageView = [_]vk.ImageView{.Null} ** FRAME_LATENCY,
    swapchain_framebuffers: [FRAME_LATENCY]vk.Framebuffer = [_]vk.Framebuffer{.Null} ** FRAME_LATENCY,

    command_pools: [FRAME_LATENCY]vk.CommandPool = [_]vk.CommandPool{.Null} ** FRAME_LATENCY,
    upload_buffers: [FRAME_LATENCY]vk.CommandBuffer = [_]vk.CommandBuffer{.Null} ** FRAME_LATENCY,
    graphics_buffers: [FRAME_LATENCY]vk.CommandBuffer = [_]vk.CommandBuffer{.Null} ** FRAME_LATENCY,

    upload_complete_sems: [FRAME_LATENCY]vk.Semaphore = [_]vk.Semaphore{.Null} ** FRAME_LATENCY,
    img_acquired_sems: [FRAME_LATENCY]vk.Semaphore = [_]vk.Semaphore{.Null} ** FRAME_LATENCY,
    swapchain_image_sems: [FRAME_LATENCY]vk.Semaphore = [_]vk.Semaphore{.Null} ** FRAME_LATENCY,
    render_complete_sems: [FRAME_LATENCY]vk.Semaphore = [_]vk.Semaphore{.Null} ** FRAME_LATENCY,

    frame_idx: u32 = 0,
    swap_img_idx: u32 = 0,
    fences: [FRAME_LATENCY]vk.Fence = [_]vk.Fence{.Null} ** FRAME_LATENCY,

    cube_gpu: cmn.GpuMesh,
    
    mesh_upload_count: u32 = 0,
    mesh_upload_queue: [MESH_UPLOAD_QUEUE_SIZE]cmn.GpuMesh = undefined,

    push_constants: cmn.PushConstants = .{
        .time = simd.Float4{0,0,0,0},
        .resolution = simd.Float2{1,1},
        .mvp = .{},
        .m = .{},
    },

    fn init(window: *sdl.Window, instance: vk.Instance) !Demo {
        const gpu = try selectGpu(instance);
        
        const gpu_props = vk.GetPhysicalDeviceProperties(gpu);

        const queue_family_count = vk.GetPhysicalDeviceQueueFamilyPropertiesCount(gpu);
        var queue_props = try allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
        errdefer allocator.free(queue_props);
        const actual_len = vk.GetPhysicalDeviceQueueFamilyProperties(gpu, queue_props).len;
        queue_props = allocator.shrink(queue_props, actual_len);

        const gpu_features = vk.GetPhysicalDeviceFeatures(gpu);
        const surface = try sdl.vulkan.createSurface(window, instance);

        var present_index: ?u32 = null;
        var graphics_index: ?u32 = null;
        for (queue_props) |*f, i| {
            const supports_present = (try vk.GetPhysicalDeviceSurfaceSupportKHR(gpu, @intCast(u32, i), surface)) != 0;
            const supports_graphics = f.queueFlags.graphics;
            if (supports_graphics and supports_present) {
                present_index = @intCast(u32, i);
                graphics_index = @intCast(u32, i);
                break;
            }
            if (supports_graphics and graphics_index == null) {
                graphics_index = @intCast(u32, i);
            }
            if (supports_present and present_index == null) {
                present_index = @intCast(u32, i);
            }
        }

        if (present_index == null) return error.NoPresentQueueFound;
        if (graphics_index == null) return error.NoGraphicsQueueFound;

        var device_ext_names: StackBuffer([*:0]const u8, MAX_EXT_COUNT) = .{};
        device_ext_names.add(vk.KHR_SWAPCHAIN_EXTENSION_NAME);

        const device = try createDevice(gpu, graphics_index.?, present_index.?, device_ext_names.span());
        const graphics_queue = vk.GetDeviceQueue(device, graphics_index.?, 0);
        const present_queue = if (present_index.? == graphics_index.?) graphics_queue
            else vk.GetDeviceQueue(device, present_index.?, 0);

        // Create Allocator
        const vma_funcs = vma.VulkanFunctions.init(instance, device, vk.vkGetInstanceProcAddr);
        const vma_alloc = try vma.Allocator.create(.{
            .physicalDevice = gpu,
            .device = device,
            .pVulkanFunctions = &vma_funcs,
            .instance = instance,
            .vulkanApiVersion = vk.API_VERSION_1_0,
            .frameInUseCount = 0,
        });

        const surface_format = blk: {
            const format_count = try vk.GetPhysicalDeviceSurfaceFormatsCountKHR(gpu, surface);
            const formats_buf = try allocator.alloc(vk.SurfaceFormatKHR, format_count);
            defer allocator.free(formats_buf);
            const formats = (try vk.GetPhysicalDeviceSurfaceFormatsKHR(gpu, surface, formats_buf)).surfaceFormats;
            break :blk pickSurfaceFormat(formats);
        };

        // Create Swapchain
        var swap_img_count: u32 = FRAME_LATENCY;
        var width: u32 = WIDTH;
        var height: u32 = HEIGHT;
        const swapchain = create_swapchain: {
            const present_mode = blk: {
                const present_mode_count = try vk.GetPhysicalDeviceSurfacePresentModesCountKHR(gpu, surface);
                const present_modes_buf = try allocator.alloc(vk.PresentModeKHR, present_mode_count);
                defer allocator.free(present_modes_buf);
                const present_modes = (try vk.GetPhysicalDeviceSurfacePresentModesKHR(gpu, surface, present_modes_buf)).presentModes;
                // The FIFO present mode is guaranteed by the spec to be supported
                // and to have no tearing.  It's a great default present mode to use.
                // ^ This comment is from the C code, but it prefers the immediate mode
                // and can only happen to choose fifo if that mode is first.
                const preferred_present_modes = [_]vk.PresentModeKHR{
                    .IMMEDIATE, .FIFO, 
                };
                const present_mode_index = std.mem.indexOfAny(vk.PresentModeKHR, present_modes, &preferred_present_modes) orelse 0;
                break :blk present_modes[present_mode_index];
            };

            const surf_caps = try vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(gpu, surface);
            var swapchain_extent: vk.Extent2D = undefined;
            // width and height are either both 0xFFFFFFFF, or both not 0xFFFFFFFF.
            if (surf_caps.currentExtent.width == 0xFFFFFFFF) {
                // If the surface size is undefined, the size is set to the size
                // of the images requested, which must fit within the minimum and
                // maximum values.
                swapchain_extent = .{
                    .width = std.math.clamp(WIDTH, surf_caps.minImageExtent.width, surf_caps.maxImageExtent.width),
                    .height = std.math.clamp(HEIGHT, surf_caps.minImageExtent.height, surf_caps.maxImageExtent.height),
                };
            } else {
                // If the surface size is defined, the swap chain size must match
                swapchain_extent = surf_caps.currentExtent;
                width = surf_caps.currentExtent.width;
                height = surf_caps.currentExtent.height;
            }

            // Determine the number of VkImages to use in the swap chain.
            // Application desires to acquire 3 images at a time for triple
            // buffering
            if (swap_img_count < surf_caps.minImageCount) {
                swap_img_count = surf_caps.minImageCount;
            }
            // If maxImageCount is 0, we can ask for as many images as we want;
            // otherwise we're limited to maxImageCount
            if ((surf_caps.maxImageCount > 0) and
                (swap_img_count > surf_caps.maxImageCount)) {
                // Application must settle for fewer images than desired:
                swap_img_count = surf_caps.maxImageCount;
            }

            var pre_transform: vk.SurfaceTransformFlagsKHR = .{};
            if (surf_caps.supportedTransforms.identity) {
                pre_transform.identity = true;
            } else {
                pre_transform = surf_caps.currentTransform;
            }

            const preferred_alpha_flags = [_]vk.CompositeAlphaFlagsKHR{
                .{ .@"opaque" = true },
                .{ .preMultiplied = true },
                .{ .postMultiplied = true },
                .{ .inherit = true },
            };
            const composite_alpha: vk.CompositeAlphaFlagsKHR =
                for (preferred_alpha_flags) |f| {
                    if (surf_caps.supportedCompositeAlpha.hasAllSet(f)) {
                        break f;
                    }
                } else .{ .@"opaque" = true };

            break :create_swapchain try vk.CreateSwapchainKHR(device, .{
                .surface = surface,
                .minImageCount = swap_img_count,
                .imageFormat = surface_format.format,
                .imageColorSpace = surface_format.colorSpace,
                .imageExtent = swapchain_extent,
                .imageArrayLayers = 1,
                .imageUsage = .{ .colorAttachment = true },
                .imageSharingMode = .EXCLUSIVE,
                .compositeAlpha = composite_alpha,
                .preTransform = pre_transform,
                .presentMode = present_mode,
                .clipped = 0,
            }, null);
        };

        // Create Render Pass
        const render_pass = create_render_pass: {
            const attachments = [_]vk.AttachmentDescription{ .{
                .format = surface_format.format,
                .samples = .{ .t1 = true },
                .loadOp = .CLEAR,
                .storeOp = .STORE,
                .stencilLoadOp = .DONT_CARE,
                .stencilStoreOp = .DONT_CARE,
                .initialLayout = .COLOR_ATTACHMENT_OPTIMAL,
                .finalLayout = .PRESENT_SRC_KHR,
            } };

            const attachment_refs = [_]vk.AttachmentReference{
                .{ .attachment = 0, .layout = .COLOR_ATTACHMENT_OPTIMAL },
            };

            const subpasses = [_]vk.SubpassDescription{ .{
                .pipelineBindPoint = .GRAPHICS,
                .colorAttachmentCount = attachment_refs.len,
                .pColorAttachments = &attachment_refs,
            } };

            break :create_render_pass try vk.CreateRenderPass(device, .{
                .attachmentCount = attachments.len,
                .pAttachments = &attachments,
                .subpassCount = subpasses.len,
                .pSubpasses = &subpasses,
            }, null);
        };

        // Create Pipeline Cache
        const pipeline_cache = try vk.CreatePipelineCache(device, .{}, null);

        // Create Graphics Pipeline Layout
        const pipeline_layout = create_layout: {
            const ranges = [_]vk.PushConstantRange{ .{
                .stageFlags = vk.ShaderStageFlags.allGraphics,
                .offset = 0,
                .size = cmn.PUSH_CONSTANT_BYTES,
            } };

            break :create_layout try vk.CreatePipelineLayout(device, .{
                .pushConstantRangeCount = ranges.len,
                .pPushConstantRanges = &ranges,
            }, null);
        };

        const fractal_pipeline = try pipelines.createFractalPipeline(device, pipeline_cache, render_pass, width, height, pipeline_layout);
        const mesh_pipeline = try pipelines.createMeshPipeline(device, pipeline_cache, render_pass, width, height, pipeline_layout);

        // Create Cube Mesh
        const cube = try cmn.GpuMesh.init(device, vma_alloc, cube_cpu);

        var d = Demo{
            .instance = instance,
            .gpu = gpu,
            .vma_allocator = vma_alloc,
            .gpu_props = gpu_props,
            .queue_props = queue_props,
            .gpu_features = gpu_features,
            .surface = surface,
            .graphics_queue_family_index = graphics_index.?,
            .present_queue_family_index = present_index.?,
            .separate_present_queue = (graphics_index.? != present_index.?),
            .device = device,
            .present_queue = present_queue,
            .graphics_queue = graphics_queue,
            .swapchain = swapchain,
            .swapchain_image_count = swap_img_count,
            .swapchain_image_format = surface_format.format,
            .swap_width = width,
            .swap_height = height,
            .render_pass = render_pass,
            .pipeline_cache = pipeline_cache,
            .pipeline_layout = pipeline_layout,
            .fractal_pipeline = fractal_pipeline,
            .mesh_pipeline = mesh_pipeline,
            .cube_gpu = cube,
        };

        d.uploadMesh(cube);

        // Create Semaphores
        {
            var i: u32 = 0;
            while (i < FRAME_LATENCY) : (i += 1) {
                d.upload_complete_sems[i] = try vk.CreateSemaphore(device, .{}, null);
                d.img_acquired_sems[i] = try vk.CreateSemaphore(device, .{}, null);
                d.swapchain_image_sems[i] = try vk.CreateSemaphore(device, .{}, null);
                d.render_complete_sems[i] = try vk.CreateSemaphore(device, .{}, null);
            }
        }

        // Get Swapchain Images
        _ = try vk.GetSwapchainImagesKHR(device, swapchain, d.swapchain_images[0..swap_img_count]);

        // Create Image Views
        {
            var create_info: vk.ImageViewCreateInfo = .{
                .viewType = .T_2D,
                .format = surface_format.format,
                .components = .{ .r=.R, .g=.G, .b=.B, .a=.A },
                .subresourceRange = .{
                    .aspectMask = .{ .color = true },
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
                .image = .Null, // will initialize in loop
            };

            var i: u32 = 0;
            while (i < FRAME_LATENCY) : (i += 1) {
                create_info.image = d.swapchain_images[i];
                d.swapchain_image_views[i] =
                    try vk.CreateImageView(device, create_info, null);
            }
        }

        // Create Framebuffers
        {
            var create_info: vk.FramebufferCreateInfo = .{
                .renderPass = render_pass,
                .width = width,
                .height = height,
                .layers = 1,
                .attachmentCount = 1,
                .pAttachments = &d.swapchain_image_views,
            };

            var i: u32 = 0;
            while (i < FRAME_LATENCY) : (i += 1) {
                d.swapchain_framebuffers[i] =
                    try vk.CreateFramebuffer(device, create_info, null);
                create_info.pAttachments += 1;
            }
        }

        // Create Command Pools
        for (d.command_pools) |*c| {
            c.* = try vk.CreateCommandPool(device, .{
                .queueFamilyIndex = graphics_index.?,
            }, null);
        }

        // Allocate Command Buffers
        {
            var alloc_info: vk.CommandBufferAllocateInfo = .{
                .level = .PRIMARY,
                .commandBufferCount = 2,
                .commandPool = .Null,
            };

            var i: u32 = 0;
            while (i < FRAME_LATENCY) : (i += 1) {
                alloc_info.commandPool = d.command_pools[i];
                var results: [2]vk.CommandBuffer = undefined;
                try vk.AllocateCommandBuffers(device, alloc_info, &results);
                d.graphics_buffers[i] = results[0];
                d.upload_buffers[i] = results[1];
            }
        }

        // Create Descriptor Set Pools
        // Create Descriptor Sets

        // Create Fences
        {
            var create_info: vk.FenceCreateInfo = .{
                .flags = .{ .signaled = true },
            };

            var i: u32 = 0;
            while (i < FRAME_LATENCY) : (i += 1) {
                d.fences[i] = try vk.CreateFence(device, create_info, null);
            }
        }

        return d;
    }

    fn renderFrame(d: *Demo) !void {
        const device = d.device;
        const swapchain = d.swapchain;
        const frame_idx = d.frame_idx;
        const fences = &d.fences;
        const graphics_queue = d.graphics_queue;
        const present_queue = d.present_queue;
        const img_acquired_sem = d.img_acquired_sems[frame_idx];
        const render_complete_sem = d.render_complete_sems[frame_idx];

        // Ensure no more than FRAME_LATENCY renderings are outstanding
        _ = vk.WaitForFences(device, arrayPtr(&fences[frame_idx]), vk.TRUE, ~@as(u64, 0)) catch unreachable;
        vk.ResetFences(device, arrayPtr(&fences[frame_idx])) catch unreachable;

        // Acquire Image
        const swap_img_idx: u32 = while (true) {
            if (vk.AcquireNextImageKHR(device, swapchain, ~@as(u64, 0), img_acquired_sem, .Null)) |result| {
                if (result.result == .SUBOPTIMAL_KHR) {
                    // demo->swapchain is not as optimal as it could be, but the platform's
                    // presentation engine will still present the image correctly.
                }
                break result.imageIndex;
            } else |err| switch (err) {
                error.VK_OUT_OF_DATE_KHR => {
                    // demo->swapchain is out of date (e.g. the window was resized) and
                    // must be recreated:
                    // resize(d);
                    // loop again
                },
                error.VK_SURFACE_LOST_KHR => {
                    // If the surface was lost we could re-create it.
                    // But the surface is owned by SDL2
                    return error.VK_SURFACE_LOST_KHR;
                },
                else => |e| return e,
            }
        } else unreachable;

        d.swap_img_idx = swap_img_idx;

        const upload_buffer = d.upload_buffers[frame_idx];
        const graphics_buffer = d.graphics_buffers[frame_idx];
        var upload_sem = vk.Semaphore.Null;

        // Render
        {
            const command_pool = d.command_pools[frame_idx];
            vk.ResetCommandPool(device, command_pool, .{}) catch unreachable;

            // Record
            {
                //Upload
                {
                    const status = vk.GetFenceStatus(device, d.cube_gpu.uploaded) catch unreachable;
                    if (status == .NOT_READY) {
                        vk.BeginCommandBuffer(upload_buffer, .{}) catch unreachable;
                        const region: vk.BufferCopy = .{
                            .srcOffset = 0, .dstOffset = 0, .size = d.cube_gpu.size,
                        };
                        vk.CmdCopyBuffer(upload_buffer, d.cube_gpu.host.buffer, d.cube_gpu.gpu.buffer, arrayPtr(&region));
                        vk.EndCommandBuffer(upload_buffer) catch unreachable;

                        upload_sem = d.upload_complete_sems[frame_idx];
                        const submit_info: vk.SubmitInfo = .{
                            .commandBufferCount = 1,
                            .pCommandBuffers = arrayPtr(&upload_buffer),
                            .signalSemaphoreCount = 1,
                            .pSignalSemaphores = arrayPtr(&upload_sem),
                        };
                        vk.QueueSubmit(d.graphics_queue, arrayPtr(&submit_info), d.cube_gpu.uploaded) catch unreachable;
                    }
                }

                vk.BeginCommandBuffer(graphics_buffer, .{}) catch unreachable;
                // Transition Swapchain Image
                {
                    var old_layout = vk.ImageLayout.UNDEFINED;
                    // Note: This can never be true, we use this var to index
                    // into buffers of length FRAME_LATENCY above.
                    if (frame_idx >= FRAME_LATENCY) {
                        old_layout = .PRESENT_SRC_KHR;
                    }

                    const barrier: vk.ImageMemoryBarrier = .{
                        .srcAccessMask = .{ .colorAttachmentRead = true },
                        .dstAccessMask = .{ .colorAttachmentWrite = true },
                        .oldLayout = old_layout,
                        .newLayout = .COLOR_ATTACHMENT_OPTIMAL,
                        .image = d.swapchain_images[frame_idx],
                        .srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
                        .dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
                        .subresourceRange = .{
                            .aspectMask = .{ .color = true },
                            .baseMipLevel = 0,
                            .levelCount = 1,
                            .baseArrayLayer = 0,
                            .layerCount = 1,
                        },
                    };
                    vk.CmdPipelineBarrier(
                        graphics_buffer,
                        .{ .colorAttachmentOutput = true }, // src stage
                        .{ .colorAttachmentOutput = true }, // dst stage
                        .{}, // dependency flags
                        &[_]vk.MemoryBarrier{},
                        &[_]vk.BufferMemoryBarrier{},
                        arrayPtr(&barrier),
                    );
                }

                // Render Pass
                {
                    const render_pass = d.render_pass;
                    const framebuffer = d.swapchain_framebuffers[frame_idx];
                    const clear_value: vk.ClearValue = .{ .color = .{
                        .float32 = .{ 0, 1, 1, 1 },
                    }};

                    const width = d.swap_width;
                    const height = d.swap_height;
                    const fwidth = @intToFloat(f32, width);
                    const fheight = @intToFloat(f32, height);

                    const full_screen_rect: vk.Rect2D = .{
                        .offset = .{ .x = 0, .y = 0 },
                        .extent = .{ .width = width, .height = height },
                    };

                    const viewport: vk.Viewport = .{
                        .x = 0,
                        .y = fheight,
                        .width = fwidth,
                        .height = -fheight,
                        .minDepth = 0,
                        .maxDepth = 1,
                    };

                    vk.CmdBeginRenderPass(graphics_buffer, .{
                        .renderPass = render_pass,
                        .framebuffer = framebuffer,
                        .renderArea = full_screen_rect,
                        .clearValueCount = 1,
                        .pClearValues = arrayPtr(&clear_value),
                    }, .INLINE);

                    // Render Setup
                    vk.CmdSetViewport(graphics_buffer, 0, arrayPtr(&viewport));
                    vk.CmdSetScissor(graphics_buffer, 0, arrayPtr(&full_screen_rect));
                    vk.CmdPushConstants(
                        graphics_buffer,
                        d.pipeline_layout,
                        vk.ShaderStageFlags.allGraphics,
                        0, // offset
                        std.mem.asBytes(&d.push_constants),
                    );

                    // Fractal
                    vk.CmdBindPipeline(graphics_buffer, .GRAPHICS, d.fractal_pipeline);
                    vk.CmdDraw(graphics_buffer, 3, 1, 0, 0);

                    // Cube
                    {
                        const idx_count = cube_cpu.index_count;
                        const vert_count = cube_cpu.vertex_count;
                        const idx_size = idx_count * (@as(usize, @sizeOf(u16)) << @intCast(u1, @enumToInt(d.cube_gpu.idx_type)));
                        const pos_size = @sizeOf(simd.Float3) * vert_count;
                        const colors_size = @sizeOf(simd.Float3) * vert_count;
                        const b = d.cube_gpu.gpu.buffer;
                        const buffers = [_]vk.Buffer{b, b, b};
                        const offsets = [_]vk.DeviceSize{
                            idx_size,
                            idx_size + pos_size,
                            idx_size + pos_size + colors_size,
                        };

                        vk.CmdBindPipeline(graphics_buffer, .GRAPHICS, d.mesh_pipeline);
                        vk.CmdBindIndexBuffer(graphics_buffer, b, 0, .UINT16);
                        vk.CmdBindVertexBuffers(graphics_buffer, 0, &buffers, &offsets);
                        vk.CmdDrawIndexed(graphics_buffer, idx_count, 1, 0, 0, 0);
                    }
                }
                vk.CmdEndRenderPass(graphics_buffer);
            }
            vk.EndCommandBuffer(graphics_buffer) catch unreachable;
        }

        // Submit
        {
            var wait_sems: StackBuffer(vk.Semaphore, 16) = .{};
            var wait_stage_flags: StackBufferAligned(vk.PipelineStageFlags, 16, 4) = .{};

            wait_sems.add(img_acquired_sem);
            wait_stage_flags.add(.{ .colorAttachmentOutput = true });

            if (upload_sem != .Null) {
                wait_sems.add(upload_sem);
                wait_stage_flags.add(.{ .transfer = true });
            }

            assert(wait_sems.count == wait_stage_flags.count);
            const submit_info: vk.SubmitInfo = .{
                .waitSemaphoreCount = @intCast(u32, wait_sems.count),
                .pWaitSemaphores = &wait_sems.buf,
                .pWaitDstStageMask = &wait_stage_flags.buf,
                .commandBufferCount = 1,
                .pCommandBuffers = arrayPtr(&graphics_buffer),
                .signalSemaphoreCount = 1,
                .pSignalSemaphores = arrayPtr(&render_complete_sem),
            };

            try vk.QueueSubmit(graphics_queue, arrayPtr(&submit_info), fences[frame_idx]);
        }

        // Present
        {
            var wait_sem = render_complete_sem;
            if (d.separate_present_queue) {
                const swapchain_sem = d.swapchain_image_sems[frame_idx];
                // If we are using separate queues, change image ownership to the
                // present queue before presenting, waiting for the draw complete
                // semaphore and signalling the ownership released semaphore when
                // finished
                const submit_info: vk.SubmitInfo = .{
                    .waitSemaphoreCount = 1,
                    .pWaitSemaphores = arrayPtr(&render_complete_sem),
                    // .commandBufferCount = 1,
                    // .pCommandBuffers =
                    //    &d->swapchain_images[swap_img_idx].graphics_to_present_cmd;
                    .signalSemaphoreCount = 1,
                    .pSignalSemaphores = arrayPtr(&swapchain_sem),
                };
                try vk.QueueSubmit(present_queue, arrayPtr(&submit_info), .Null);

                wait_sem = swapchain_sem;
            }

            const present_result = vk.QueuePresentKHR(present_queue, .{
                .waitSemaphoreCount = 1,
                .pWaitSemaphores = arrayPtr(&wait_sem),
                .swapchainCount = 1,
                .pSwapchains = arrayPtr(&swapchain),
                .pImageIndices = arrayPtr(&swap_img_idx),
            });

            d.frame_idx = (frame_idx + 1) % FRAME_LATENCY;

            if (present_result) |result| {
                if (result == .SUBOPTIMAL_KHR) {
                    // demo->swapchain is not as optimal as it could be, but the platform's
                    // presentation engine will still present the image correctly.
                }
            } else |err| switch (err) {
                error.VK_OUT_OF_DATE_KHR => {
                    // demo->swapchain is out of date (e.g. the window was resized) and
                    // must be recreated:
                    // resize(d);
                },
                error.VK_SURFACE_LOST_KHR => {
                    // If the surface was lost we could re-create it.
                    // But the surface is owned by SDL2
                    return error.VK_SURFACE_LOST_KHR;
                },
                else => |e| return e,
            }
        }
    }

    fn deinit(d: *Demo) void {
        const device = d.device;

        vk.DeviceWaitIdle(device) catch {};

        var i: u32 = 0;
        while (i < FRAME_LATENCY) : (i += 1) {
            vk.DestroyFence(device, d.fences[i], null);
            vk.DestroySemaphore(device, d.upload_complete_sems[i], null);
            vk.DestroySemaphore(device, d.render_complete_sems[i], null);
            vk.DestroySemaphore(device, d.swapchain_image_sems[i], null);
            vk.DestroySemaphore(device, d.img_acquired_sems[i], null);
            vk.DestroyImageView(device, d.swapchain_image_views[i], null);
            vk.DestroyFramebuffer(device, d.swapchain_framebuffers[i], null);
            vk.DestroyCommandPool(device, d.command_pools[i], null);
        }

        d.cube_gpu.deinit(device, d.vma_allocator);

        allocator.free(d.queue_props);
        vk.DestroyPipelineLayout(device, d.pipeline_layout, null);
        vk.DestroyPipeline(device, d.mesh_pipeline, null);
        vk.DestroyPipeline(device, d.fractal_pipeline, null);
        vk.DestroyPipelineCache(device, d.pipeline_cache, null);
        vk.DestroyRenderPass(device, d.render_pass, null);
        vk.DestroySwapchainKHR(device, d.swapchain, null);
        vk.DestroySurfaceKHR(d.instance, d.surface, null);
        d.vma_allocator.destroy();
        vk.DestroyDevice(d.device, null);

        d.* = undefined;
    }

    fn uploadMesh(demo: *Demo, m: cmn.GpuMesh) void {
        const idx = demo.mesh_upload_count;
        demo.mesh_upload_queue[idx] = m;
        demo.mesh_upload_count = idx + 1;
    }
};

fn hasLayer(name: []const u8, layers: []const vk.LayerProperties) bool {
    for (layers) |*layer| {
        const layer_name = std.mem.sliceTo(&layer.layerName, 0);
        if (std.mem.eql(u8, name, layer_name)) {
            return true;
        }
    }
    return false;
}

fn selectGpu(instance: vk.Instance) !vk.PhysicalDevice {
    const num_physical_devices = try vk.EnumeratePhysicalDevicesCount(instance);
    const physical_devices_buf = try allocator.alloc(vk.PhysicalDevice, num_physical_devices);
    defer allocator.free(physical_devices_buf);
    const physical_devices = (try vk.EnumeratePhysicalDevices(instance, physical_devices_buf)).physicalDevices;

    const NUM_PHYS_DEVICE_TYPES = @enumToInt(vk.PhysicalDeviceType.CPU) + 1;
    var first_device_by_type = [_]?u32{null} ** NUM_PHYS_DEVICE_TYPES;
    for (physical_devices) |device, i| {
        const properties = vk.GetPhysicalDeviceProperties(device);
        const type_index = @intCast(usize, @enumToInt(properties.deviceType));
        // the bounds assert from the C code is generated by the zig
        // compiler automatically, we don't need to write it out.
        if (first_device_by_type[type_index] == null) {
            first_device_by_type[type_index] = @intCast(u32, i);
        }
    }

    const preferred_device_types = [_]vk.PhysicalDeviceType{
        .DISCRETE_GPU, .INTEGRATED_GPU, .VIRTUAL_GPU, .CPU, .OTHER
    };
    for (preferred_device_types) |dev_type| {
        if (first_device_by_type[@intCast(usize, @enumToInt(dev_type))]) |device_index| {
            return physical_devices[device_index];
        }
    }

    return error.NoSuitableGPU;
}

fn createDevice(
    gpu: vk.PhysicalDevice,
    graphics_queue_family_index: u32,
    present_queue_family_index: u32,
    extensions: []const [*:0]const u8,
) !vk.Device {
    const queue_priorities = [_]f32{ 0 };
    const queues = [_]vk.DeviceQueueCreateInfo{
        .{
            .queueFamilyIndex = graphics_queue_family_index,
            .queueCount = queue_priorities.len,
            .pQueuePriorities = &queue_priorities,
        },
        .{
            .queueFamilyIndex = present_queue_family_index,
            .queueCount = queue_priorities.len,
            .pQueuePriorities = &queue_priorities,
        },
    };

    const num_queues: u32 = if (graphics_queue_family_index == present_queue_family_index) 1 else 2;

    return try vk.CreateDevice(gpu, .{
        .pQueueCreateInfos = &queues,
        .queueCreateInfoCount = num_queues,
        .enabledExtensionCount = @intCast(u32, extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
    }, null);
}

fn pickSurfaceFormat(formats: []const vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
    const desired_formats = [_]vk.Format{
        .R8G8B8A8_UNORM,
        .B8G8R8A8_UNORM,
        .A2B10G10R10_UNORM_PACK32,
        .A2R10G10B10_UNORM_PACK32,
        .R16G16B16A16_SFLOAT,
    };

    for (desired_formats) |target| {
        for (formats) |f| {
            if (f.format == target) {
                return f;
            }
        }
    }
    return formats[0];
}

fn StackBuffer(comptime T: type, comptime N: usize) type {
    return StackBufferAligned(T, N, null);
}

fn StackBufferAligned(comptime T: type, comptime N: usize, comptime alignment: ?usize) type {
    return struct {
        const Self = @This();

        buf: [N]T align(alignment orelse @alignOf(T)) = undefined,
        count: usize = 0,

        pub fn add(self: *Self, value: T) void {
            // Compiler adds a length assert, we don't need one.
            self.buf[self.count] = value;
            self.count += 1;
        }

        pub fn span(self: *Self) []align(alignment orelse @alignOf(T)) T {
            return self.buf[0..self.count];
        }
    };
}
