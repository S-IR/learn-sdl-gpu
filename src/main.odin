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

trianglePositions := [3]float3{{0.5, -0.5, 0.0}, {-0.5, -0.5, 0.0}, {0.0, 0.5, 0.0}}

main :: proc() {
	fmt.println("hello world")

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
				num_vertex_buffers = 1,
				vertex_buffer_descriptions = raw_data(
					[]sdl.GPUVertexBufferDescription {
						{
							slot = 0,
							instance_step_rate = 0,
							input_rate = .VERTEX,
							pitch = size_of(float3),
						},
					},
				),
				num_vertex_attributes = 1,
				vertex_attributes = raw_data(
					[]sdl.GPUVertexAttribute {
						{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
					},
				),
			},
			primitive_type = .TRIANGLELIST,
			vertex_shader = vertexShader,
			fragment_shader = fragmentShader,
		},
	)

	sdl_ensure(pipeline != nil)
	sdl.ReleaseGPUShader(device, vertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)


	vertexBuffer := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(trianglePositions))},
	)

	gpu_buffer_upload(&vertexBuffer, raw_data(&trianglePositions), size_of(trianglePositions))


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
		sdl.BindGPUVertexBuffers(
			renderPass,
			0,
			raw_data([]sdl.GPUBufferBinding{{buffer = vertexBuffer, offset = 0}}),
			1,
		)
		sdl.DrawGPUPrimitives(renderPass, 3, 1, 0, 0)
		sdl.EndGPURenderPass(renderPass)

	}
}
