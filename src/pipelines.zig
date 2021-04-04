usingnamespace @import("common.zig");

const mesh_vert_shader = @embedFile("shader_data/mesh_vert.spv");
const mesh_frag_shader = @embedFile("shader_data/mesh_frag.spv");
const fractal_vert_shader = @embedFile("shader_data/fractal_vert.spv");
const fractal_frag_shader = @embedFile("shader_data/fractal_frag.spv");

pub fn createMeshPipeline(
    device: vk.Device,
    cache: vk.PipelineCache,
    pass: vk.RenderPass,
    w: u32,
    h: u32,
    layout: vk.PipelineLayout,
) !vk.Pipeline {
    const vert_bindings = [_]vk.VertexInputBindingDescription{
        .{ .binding = 0, .stride = @sizeOf(Float3), .inputRate = .VERTEX },
        .{ .binding = 1, .stride = @sizeOf(Float3), .inputRate = .VERTEX },
        .{ .binding = 2, .stride = @sizeOf(Float3), .inputRate = .VERTEX },
    };

    const vert_attrs = [_]vk.VertexInputAttributeDescription{
        .{ .location = 0, .binding = 0, .format = .R32G32B32_SFLOAT, .offset = 0 },
        .{ .location = 1, .binding = 1, .format = .R32G32B32_SFLOAT, .offset = 0 },
        .{ .location = 2, .binding = 2, .format = .R32G32B32_SFLOAT, .offset = 0 },
    };

    const vert_input_state: vk.PipelineVertexInputStateCreateInfo = .{
        .vertexBindingDescriptionCount = vert_bindings.len,
        .pVertexBindingDescriptions = &vert_bindings,
        .vertexAttributeDescriptionCount = vert_attrs.len,
        .pVertexAttributeDescriptions = &vert_attrs,
    };

    return try createPipeline(
        device,
        cache,
        pass,
        w,
        h,
        layout,
        mesh_vert_shader,
        mesh_frag_shader,
        vert_input_state,
    );
}

pub fn createFractalPipeline(
    device: vk.Device,
    cache: vk.PipelineCache,
    pass: vk.RenderPass,
    w: u32,
    h: u32,
    layout: vk.PipelineLayout,
) !vk.Pipeline {
    return try createPipeline(
        device,
        cache,
        pass,
        w,
        h,
        layout,
        fractal_vert_shader,
        fractal_frag_shader,
        .{}, // vertex format, no verts here
    );
}

fn createPipeline(
    device: vk.Device,
    cache: vk.PipelineCache,
    pass: vk.RenderPass,
    w: u32,
    h: u32,
    layout: vk.PipelineLayout,
    vert_spv: []const u8,
    frag_spv: []const u8,
    vertex_format: vk.PipelineVertexInputStateCreateInfo,
) !vk.Pipeline {
    const vert_mod = try vk.CreateShaderModule(device, .{
        .codeSize = vert_spv.len,
        .pCode = @ptrCast([*]const u32, @alignCast(4, vert_spv)),
    }, null);
    defer vk.DestroyShaderModule(device, vert_mod, null);

    const frag_mod = try vk.CreateShaderModule(device, .{
        .codeSize = frag_spv.len,
        .pCode = @ptrCast([*]const u32, @alignCast(4, frag_spv)),
    }, null);
    defer vk.DestroyShaderModule(device, frag_mod, null);

    const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
        .{ .stage = .{ .vertex = true }, .module = vert_mod, .pName = "vert" },
        .{ .stage = .{ .fragment = true }, .module = frag_mod, .pName = "frag" },
    };

    const input_assembly_state: vk.PipelineInputAssemblyStateCreateInfo = .{
        .topology = .TRIANGLE_LIST,
        .primitiveRestartEnable = 0,
    };

    const fw = @intToFloat(f32, w);
    const fh = @intToFloat(f32, h);

    const viewports = [_]vk.Viewport{ .{
        .x = 0,
        .y = fh,
        .width = fw,
        .height = -fh,
        .minDepth = 0,
        .maxDepth = 1,
    } };

    const scissors = [_]vk.Rect2D{ .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{ .width = w, .height = h },
    } };

    const viewport_state: vk.PipelineViewportStateCreateInfo = .{
        .viewportCount = viewports.len,
        .pViewports = &viewports,
        .scissorCount = scissors.len,
        .pScissors = &scissors,
    };

    const raster_state = std.mem.zeroInit(vk.PipelineRasterizationStateCreateInfo, .{
        .polygonMode = .FILL,
        .cullMode = .{ .back = true },
        .frontFace = .COUNTER_CLOCKWISE,
        .lineWidth = 1,
    });

    const multisample_state = std.mem.zeroInit(vk.PipelineMultisampleStateCreateInfo, .{
        .rasterizationSamples = .{ .t1 = true },
    });

    const depth_state = std.mem.zeroInit(vk.PipelineDepthStencilStateCreateInfo, .{
        .maxDepthBounds = 1,
    });

    const attachment_states = [_]vk.PipelineColorBlendAttachmentState{ 
        std.mem.zeroInit(vk.PipelineColorBlendAttachmentState, .{
            .colorWriteMask = .{ .r=true, .g=true, .b=true, .a=true },
        }),
    };

    const color_blend_state = std.mem.zeroInit(vk.PipelineColorBlendStateCreateInfo, .{
        .attachmentCount = attachment_states.len,
        .pAttachments = &attachment_states,
    });

    const dyn_states = [_]vk.DynamicState{ .VIEWPORT, .SCISSOR };
    const dynamic_state: vk.PipelineDynamicStateCreateInfo = .{
        .dynamicStateCount = dyn_states.len,
        .pDynamicStates = &dyn_states,
    };

    const create_infos = [_]vk.GraphicsPipelineCreateInfo{ .{
        .stageCount = shader_stages.len,
        .pStages = &shader_stages,
        .pVertexInputState = &vertex_format,
        .pInputAssemblyState = &input_assembly_state,
        .pViewportState = &viewport_state,
        .pRasterizationState = &raster_state,
        .pMultisampleState = &multisample_state,
        .pDepthStencilState = &depth_state,
        .pColorBlendState = &color_blend_state,
        .pDynamicState = &dynamic_state,
        .layout = layout,
        .renderPass = pass,
        .subpass = 0,
        .basePipelineHandle = .Null,
        .basePipelineIndex = 0,
    } };

    var pipelines = [_]vk.Pipeline{ .Null };
    try vk.CreateGraphicsPipelines(device, cache, &create_infos, null, &pipelines);

    return pipelines[0];
}
