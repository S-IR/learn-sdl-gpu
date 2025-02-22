package main
import "core:fmt"
import "core:math"
import "core:mem"
import "core:path/filepath"
import sdl "vendor:sdl3"

sdl_ensure :: proc(cond: bool, message: string = "") {
	msg := fmt.tprintf("%s:%s\n", message, sdl.GetError())
	ensure(cond, msg)

}

device: ^sdl.GPUDevice
window: ^sdl.Window

float2 :: [2]f32
float3 :: [3]f32

AtlasIndex :: enum u8 {
	Dirt,
	Stone,
	Grass,
	DieHard,
}
TOTAL_VERTICES :: 4
quadPositions := [TOTAL_VERTICES]float3 {
	{-0.5, -0.5, 0.0}, // 0: bottom left
	{-0.5, 0.5, 0.0}, // 1: top left
	{0.5, -0.5, 0.0}, // 2: bottom right
	{0.5, 0.5, 0.0}, // 3: top right
}
quadUV := [TOTAL_VERTICES]float2 {
	{0, 1}, // 0: bottom left
	{0, 0}, // 1: top left
	{1, 1}, // 2: bottom right
	{1, 0}, // 3: top right
}


quadColors := [TOTAL_VERTICES]float3{{0, 0, .2}, {0, 0, .4}, {0, 0, .6}, {0, 0, .8}}
quadIndices := [6]u16{0, 1, 2, 1, 2, 3}

AtlasUBO :: struct {
	tileSize:   float2,
	atlasIndex: float2,
}

tileWidth: f32 : 2
tileHeight: f32 : 2

tileSize :: float2{1.0 / tileWidth, 1.0 / tileHeight}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	width := 1280
	height := 720
	sdl_ensure(sdl.Init({.VIDEO}))
	window = sdl.CreateWindow("Learn SDL Gpu", i32(width), i32(height), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)

	device = sdl.CreateGPUDevice({.SPIRV, .DXIL}, true, nil)
	sdl_ensure(device != nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(device, window) != false)

	vertexShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "shader.vert.spv"},
			allocator = context.temp_allocator,
		),
		{UBOs = 1},
	)


	fragmentShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "shader.frag.spv"},
			allocator = context.temp_allocator,
		),
		{samplers = 1, UBOs = 1},
	)

	pipeline := sdl.CreateGPUGraphicsPipeline(
		device,
		sdl.GPUGraphicsPipelineCreateInfo {
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = raw_data(
					[]sdl.GPUColorTargetDescription {
						{format = sdl.GetGPUSwapchainTextureFormat(device, window)},
					},
				),
			},
			vertex_input_state = {
				num_vertex_buffers = 3,
				vertex_buffer_descriptions = raw_data(
					[]sdl.GPUVertexBufferDescription {
						{
							slot = 0,
							instance_step_rate = 0,
							input_rate = .VERTEX,
							pitch = size_of(float3),
						},
						{
							slot = 1,
							instance_step_rate = 0,
							input_rate = .VERTEX,
							pitch = size_of(float3),
						},
						{
							slot = 2,
							instance_step_rate = 0,
							input_rate = .VERTEX,
							pitch = size_of(float2),
						},
					},
				),
				num_vertex_attributes = 3,
				vertex_attributes = raw_data(
					[]sdl.GPUVertexAttribute {
						{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
						{buffer_slot = 1, format = .FLOAT3, location = 1, offset = 0},
						{buffer_slot = 2, format = .FLOAT2, location = 2, offset = 0},
					},
				),
			},
			primitive_type = .TRIANGLELIST,
			vertex_shader = vertexShader,
			fragment_shader = fragmentShader,
		},
	)

	sdl_ensure(pipeline != nil)
	defer sdl.ReleaseGPUGraphicsPipeline(device, pipeline)

	sdl.ReleaseGPUShader(device, vertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)


	positions := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(quadPositions))},
	)
	sdl_ensure(positions != nil)
	defer sdl.ReleaseGPUBuffer(device, positions)
	gpu_buffer_upload(&positions, raw_data(&quadPositions), size_of(quadPositions))
	sdl.SetGPUBufferName(device, positions, "positions")


	colors := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(quadColors))},
	)
	sdl_ensure(colors != nil)
	defer sdl.ReleaseGPUBuffer(device, colors)
	sdl.SetGPUBufferName(device, colors, "colors")
	gpu_buffer_upload(&colors, raw_data(&quadColors), size_of(quadColors))

	indices := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = size_of(quadIndices)},
	)
	sdl_ensure(indices != nil)
	defer sdl.ReleaseGPUBuffer(device, indices)
	sdl.SetGPUBufferName(device, indices, "indices")
	gpu_buffer_upload(&indices, raw_data(&quadIndices), size_of(quadIndices))

	uvs := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = size_of(quadUV)},
	)
	sdl_ensure(uvs != nil)
	defer sdl.ReleaseGPUBuffer(device, uvs)
	sdl.SetGPUBufferName(device, uvs, "uvs")
	gpu_buffer_upload(&uvs, raw_data(&quadUV), size_of(quadUV))


	texture := load_image(
		filepath.join({"resources", "images", "atlas.jpg"}, allocator = context.temp_allocator),
	)
	sdl_ensure(texture != nil)
	defer sdl.ReleaseGPUTexture(device, texture)

	sampler := sdl.CreateGPUSampler(
		device,
		sdl.GPUSamplerCreateInfo {
			min_filter = .LINEAR,
			mag_filter = .LINEAR,
			mipmap_mode = .NEAREST,
			address_mode_u = .CLAMP_TO_EDGE,
			address_mode_v = .CLAMP_TO_EDGE,
			address_mode_w = .CLAMP_TO_EDGE,
		},
	)
	sdl_ensure(sampler != nil)
	defer sdl.ReleaseGPUSampler(device, sampler)


	e: sdl.Event
	quit := false

	chosenIndex: AtlasIndex = .Dirt
	free_all(context.temp_allocator)
	for !quit {
		for sdl.PollEvent(&e) {
			#partial switch e.type {
			case .QUIT:
				quit = true
				break
			case .KEY_DOWN:
				if e.key.key == sdl.K_ESCAPE {
					quit = true
				}

			// switch e.key.key {
			// case sdl.K_A:
			// 	chosenIndex = .Dirt
			// case sdl.K_W:
			// 	chosenIndex = .Stone
			// case sdl.K_S:
			// 	chosenIndex = .Grass
			// case sdl.K_D:
			// 	chosenIndex = .DieHard

			// }
			case .WINDOW_RESIZED:
				screenWidth, screenHeight := e.window.data1, e.window.data2

				sdl.SetWindowSize(window, screenWidth, screenHeight)
				sdl.SyncWindow(window)

			case:
				continue
			}
		}

		cmdBuf := sdl.AcquireGPUCommandBuffer(device)
		if cmdBuf == nil do continue
		defer sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdBuf) != false)

		swapTexture: ^sdl.GPUTexture
		if sdl.WaitAndAcquireGPUSwapchainTexture(cmdBuf, window, &swapTexture, nil, nil) == false do continue
		colorTargetInfo := sdl.GPUColorTargetInfo {
			texture     = swapTexture,
			clear_color = {0.3, 0.2, 0.7, 1.0},
			load_op     = .CLEAR,
			store_op    = .STORE,
		}
		renderPass := sdl.BeginGPURenderPass(cmdBuf, &colorTargetInfo, 1, nil)

		column := i32(chosenIndex) % i32(tileWidth)
		row := i32(chosenIndex) / i32(tileWidth)
		atlasIndex := float2{f32(column), f32(row)}
		sdl.BindGPUGraphicsPipeline(renderPass, pipeline)

		assert(positions != nil)
		assert(colors != nil)
		assert(uvs != nil)

		bufferBindings := [?]sdl.GPUBufferBinding {
			{buffer = positions, offset = 0},
			{buffer = colors, offset = 0},
			{buffer = uvs, offset = 0},
		}

		atlasUbo: AtlasUBO = {tileSize, atlasIndex}
		sdl.PushGPUVertexUniformData(cmdBuf, 0, &atlasUbo, size_of(atlasUbo))

		sdl.BindGPUVertexBuffers(renderPass, 0, raw_data(&bufferBindings), len(bufferBindings))
		sdl.BindGPUIndexBuffer(renderPass, {buffer = indices, offset = 0}, ._16BIT)

		assert(texture != nil)
		assert(sampler != nil)

		sdl.BindGPUFragmentSamplers(
			renderPass,
			0,
			raw_data([]sdl.GPUTextureSamplerBinding{{texture = texture, sampler = sampler}}),
			1,
		)
		sdl.DrawGPUIndexedPrimitives(renderPass, len(quadIndices), 1, 0, 0, 0)
		sdl.EndGPURenderPass(renderPass)

	}
}
