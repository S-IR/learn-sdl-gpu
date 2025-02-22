package main
import "core:fmt"
import "core:path/filepath"
import sdl "vendor:sdl3"
sdl_ensure :: proc(cond: bool, message: string = "") {
	msg := fmt.tprintf("%s:%s\n", message, sdl.GetError())
	ensure(cond, msg)

}

device: ^sdl.GPUDevice
window: ^sdl.Window

float3 :: [3]f32

quadPositions := [4]float3{{-0.5, -0.5, 0.0}, {-0.5, 0.5, 0.0}, {0.5, -0.5, 0.0}, {0.5, 0.5, 0.0}}
quadColors := [4]float3{{0, 0, .2}, {0, 0, .4}, {0, 0, .6}, {0, 0, .8}}
quadIndices := [6]u16{0, 1, 2, 1, 2, 3}

main :: proc() {

	width := 1280
	height := 720
	sdl_ensure(sdl.Init({.VIDEO}))
	window = sdl.CreateWindow("Learn SDL Gpu", i32(width), i32(height), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)

	device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
	sdl_ensure(device != nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(device, window) != false)

	vertexShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "shader.vert.spv"},
			allocator = context.temp_allocator,
		),
		{},
	)


	fragmentShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "shader.frag.spv"},
			allocator = context.temp_allocator,
		),
		{},
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
				num_vertex_buffers = 2,
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
					},
				),
				num_vertex_attributes = 2,
				vertex_attributes = raw_data(
					[]sdl.GPUVertexAttribute {
						{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
						{buffer_slot = 1, format = .FLOAT3, location = 1, offset = 0},
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


	e: sdl.Event
	quit := false

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
		sdl.BindGPUGraphicsPipeline(renderPass, pipeline)

		bufferBindings := [?]sdl.GPUBufferBinding {
			{buffer = positions, offset = 0},
			{buffer = colors, offset = 0},
		}

		sdl.BindGPUVertexBuffers(renderPass, 0, raw_data(&bufferBindings), len(bufferBindings))
		sdl.BindGPUIndexBuffer(renderPass, {buffer = indices, offset = 0}, ._16BIT)


		sdl.DrawGPUIndexedPrimitives(renderPass, len(quadIndices), 2, 0, 0, 0)
		sdl.EndGPURenderPass(renderPass)

	}
}
