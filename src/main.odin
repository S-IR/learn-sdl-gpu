package main
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"

sdl_ensure :: proc(cond: bool, message: string = "") {
	msg := fmt.tprintf("%s:%s\n", message, sdl.GetError())
	ensure(cond, msg)
}

device: ^sdl.GPUDevice
window: ^sdl.Window

float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32

AtlasIndex :: enum u8 {
	Dirt,
	Stone,
	Grass,
	DieHard,
}
TOTAL_VERTICES :: 24

AtlasUBO :: struct {
	tileSize: float2,
}

tileWidth: f32 : 2
tileHeight: f32 : 2


GRID_SIZE :: 5

CubeInfo :: struct {
	worldPosition: float3,
	_pad0:         f32,
	index:         float2,
	_pad1:         float2,
}


cubes := [GRID_SIZE * GRID_SIZE]CubeInfo{}

tileSize :: float2{1.0 / tileWidth, 1.0 / tileHeight}


dt: f64


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

	width: i32 = 1280
	height: i32 = 720
	sdl_ensure(sdl.Init({.VIDEO}))
	window = sdl.CreateWindow("Learn SDL Gpu", i32(width), i32(height), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)

	device = sdl.CreateGPUDevice({.SPIRV}, ODIN_DEBUG, nil)
	sdl_ensure(device != nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(device, window) != false)

	vertexShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "cube.vertex.spv"},
			allocator = context.temp_allocator,
		),
		{UBOs = 2, SBOs = 1},
	)

	fragmentShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "cube.fragment.spv"},
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
				has_depth_stencil_target = true,
				depth_stencil_format = .D24_UNORM,
			},
			depth_stencil_state = sdl.GPUDepthStencilState {
				enable_depth_test = true,
				enable_depth_write = true,
				enable_stencil_test = false,
				compare_op = .LESS,
				write_mask = 0xFF,
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
							pitch = size_of(float2),
						},
					},
				),
				num_vertex_attributes = 2,
				vertex_attributes = raw_data(
					[]sdl.GPUVertexAttribute {
						{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
						{buffer_slot = 1, format = .FLOAT2, location = 1, offset = 0},
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


	sdl.GetWindowSizeInPixels(window, &width, &height)
	depthTexture := sdl.CreateGPUTexture(
		device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			width = u32(width),
			height = u32(height),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			format = .D24_UNORM,
			usage = {.DEPTH_STENCIL_TARGET},
		},
	)
	defer sdl.ReleaseGPUTexture(device, depthTexture)

	positions := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(cubePositions))},
	)
	sdl_ensure(positions != nil)
	defer sdl.ReleaseGPUBuffer(device, positions)
	sdl.SetGPUBufferName(device, positions, "positions")
	gpu_buffer_upload(&positions, raw_data(&cubePositions), size_of(cubePositions))

	colors := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(cubeColors))},
	)
	sdl_ensure(colors != nil)
	defer sdl.ReleaseGPUBuffer(device, colors)
	sdl.SetGPUBufferName(device, colors, "colors")
	gpu_buffer_upload(&colors, raw_data(&cubeColors), size_of(cubeColors))


	uvs := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = size_of(cubeUV)},
	)
	sdl_ensure(uvs != nil)
	defer sdl.ReleaseGPUBuffer(device, uvs)
	sdl.SetGPUBufferName(device, uvs, "uvs")
	gpu_buffer_upload(&uvs, raw_data(&cubeUV), size_of(cubeUV))


	indices := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = size_of(cubeIndices)},
	)
	sdl_ensure(indices != nil)
	defer sdl.ReleaseGPUBuffer(device, indices)
	sdl.SetGPUBufferName(device, indices, "indices")
	gpu_buffer_upload(&indices, raw_data(&cubeIndices), size_of(cubeIndices))


	cubeSBO := sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(cubes)},
	)
	defer sdl.ReleaseGPUBuffer(device, cubeSBO)
	sdl.SetGPUBufferName(device, cubeSBO, "cubeSBO")

	{
		for x in 0 ..< GRID_SIZE {
			for z in 0 ..< GRID_SIZE {
				chosenIndex: AtlasIndex = .Grass

				column := i32(chosenIndex) % i32(tileWidth)
				row := i32(chosenIndex) / i32(tileWidth)
				atlasIndex := float2{f32(column), f32(row)}


				cubes[x * GRID_SIZE + z] = CubeInfo {
					worldPosition = {f32(x), 0, f32(z)},
					index         = atlasIndex,
				}
			}
		}
		gpu_buffer_upload(&cubeSBO, raw_data(&cubes), size_of(cubes))

	}


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

	free_all(context.temp_allocator)


	lastFrameTime := time.now()
	FPS :: 144
	frameTime := time.Duration(time.Second / FPS)

	currRotationAngle: f32 = 0
	ROTATION_SPEED :: 90

	for !quit {
		defer {
			frameEnd := time.now()
			frameDuration := time.diff(frameEnd, lastFrameTime)


			if frameDuration < frameTime {
				sleepTime := frameTime - frameDuration
				time.sleep(sleepTime)
			}

			dt = time.duration_seconds(time.since(lastFrameTime))
			lastFrameTime = time.now()
		}

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

				sdl.ReleaseGPUTexture(device, depthTexture)
				depthTexture = sdl.CreateGPUTexture(
					device,
					sdl.GPUTextureCreateInfo {
						type = .D2,
						width = u32(screenWidth),
						height = u32(screenHeight),
						layer_count_or_depth = 1,
						num_levels = 1,
						sample_count = ._1,
						format = .D24_UNORM,
						usage = {.DEPTH_STENCIL_TARGET},
					},
				)

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
		depthStencilTargetInfo: sdl.GPUDepthStencilTargetInfo = {
			texture          = depthTexture,
			cycle            = true,
			clear_depth      = 1,
			clear_stencil    = 0,
			load_op          = .CLEAR,
			store_op         = .STORE,
			stencil_load_op  = .CLEAR,
			stencil_store_op = .STORE,
		}


		renderPass := sdl.BeginGPURenderPass(cmdBuf, &colorTargetInfo, 1, &depthStencilTargetInfo)
		sdl.BindGPUGraphicsPipeline(renderPass, pipeline)

		assert(positions != nil)
		assert(uvs != nil)
		assert(cubeSBO != nil)

		sdl.BindGPUVertexStorageBuffers(renderPass, 0, &cubeSBO, 1)

		currRotationAngle += f32(dt) * ROTATION_SPEED

		radius: f32 : 3

		cameraX := radius * math.cos(currRotationAngle * math.RAD_PER_DEG)
		cameraZ := radius * math.sin(currRotationAngle * math.RAD_PER_DEG)

		cameraPos := float3{cameraX, 3, cameraZ}

		view := linalg.matrix4_look_at_f32(cameraPos, {0, 0, 0}, {0, 1, 0})
		FOV :: 45
		NEAR_PLANE: f32 : 0.2
		FAR_PLANE: f32 : 160.0
		proj := linalg.matrix4_perspective_f32(
			FOV,
			f32(width) / f32(height),
			NEAR_PLANE,
			FAR_PLANE,
		)

		viewProj := [2]matrix[4, 4]f32{view, proj}
		sdl.PushGPUVertexUniformData(cmdBuf, 0, &viewProj, size_of(viewProj))


		bufferBindings := [?]sdl.GPUBufferBinding {
			{buffer = positions, offset = 0},
			{buffer = uvs, offset = 0},
		}

		atlasUbo: AtlasUBO = {tileSize}

		sdl.PushGPUVertexUniformData(cmdBuf, 1, &atlasUbo, size_of(atlasUbo))

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
		sdl.DrawGPUIndexedPrimitives(renderPass, len(cubeIndices), GRID_SIZE * GRID_SIZE, 0, 0, 0)
		sdl.EndGPURenderPass(renderPass)

	}
}
