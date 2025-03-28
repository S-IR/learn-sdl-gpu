package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"
TOTAL_CUBE_VERTICES :: 24

tileRows: f32 : 2
tileCols: f32 : 2
ATLAS_NUM_OF_TILES :: float2{tileRows, tileCols}
CubeAtlasIndex :: enum u32 {
	Dirt,
	Stone,
	Grass,
	DieHard,
	Air,
}

CubeAtlasUBO :: struct {
	tiles:    float2,
	tileSize: float2,
}

GRID_X_LEN :: 20
GRID_Y_LEN :: 20
GRID_Z_LEN :: 20

CubeInfo :: struct {
	worldPosition: float3,
	atlasIndex:    u32,
}


cubes := [GRID_X_LEN * GRID_Y_LEN * GRID_Z_LEN]CubeInfo{}
ATLAS_TILE_SIZE :: float2{1.0 / tileRows, 1.0 / tileCols}


cubePositions := [24]float3 {
	// front face
	{-0.5, -0.5, 0.5}, //  left bottom front  
	{-0.5, 0.5, 0.5}, //   left top front 
	{0.5, 0.5, 0.5}, //  right top front  
	{0.5, -0.5, 0.5}, //  right bottom front

	// back face
	{-0.5, -0.5, -0.5}, // Back bottom left 
	{-0.5, 0.5, -0.5}, // Back top left     
	{0.5, 0.5, -0.5}, // Back top right     
	{0.5, -0.5, -0.5}, // Back bottom right 

	// right face
	{0.5, -0.5, -0.5}, // Right bottom back
	{0.5, 0.5, -0.5}, // Right top back    
	{0.5, 0.5, 0.5}, // Right top front    
	{0.5, -0.5, 0.5}, // Right bottom front

	// left face
	{-0.5, -0.5, -0.5}, // Left bottom back
	{-0.5, 0.5, -0.5}, // Left top back    
	{-0.5, 0.5, 0.5}, // Left top front    
	{-0.5, -0.5, 0.5}, // Left bottom front

	// top face
	{-0.5, 0.5, -0.5}, // Top back left    
	{0.5, 0.5, -0.5}, // Top back right    
	{0.5, 0.5, 0.5}, // Top front right    
	{-0.5, 0.5, 0.5}, // Top front left    

	//bottom face
	{-0.5, -0.5, 0.5}, // Bottom front left
	{-0.5, -0.5, -0.5}, // Bottom back left
	{0.5, -0.5, -0.5}, // Bottom back right
	{0.5, -0.5, 0.5}, // Bottom front right
}

cubeIndices := [36]u16 {
	// Back face 
	0,
	2,
	1,
	0,
	3,
	2,
	// Front face 
	0 + 4,
	1 + 4,
	2 + 4,
	0 + 4,
	2 + 4,
	3 + 4,
	// Right facet
	0 + 8,
	1 + 8,
	2 + 8,
	0 + 8,
	2 + 8,
	3 + 8,
	// Left face 
	0 + 12,
	2 + 12,
	1 + 12,
	0 + 12,
	3 + 12,
	2 + 12,
	// Top face
	0 + 16,
	2 + 16,
	1 + 16,
	0 + 16,
	3 + 16,
	2 + 16,
	// Bottom face 
	0 + 20,
	1 + 20,
	2 + 20,
	0 + 20,
	2 + 20,
	3 + 20,
}

cubeUV := [TOTAL_CUBE_VERTICES]float2 {
	//front
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//back
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//right
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//left
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//top
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
	//bottom
	{0, 0},
	{1, 0},
	{1, 1},
	{0, 1},
}


R_cube: struct {
	vertexShaderInfo:   ShaderInfo,
	fragmentShaderInfo: ShaderInfo,
	pipeline:           ^sdl.GPUGraphicsPipeline,
	positions:          ^sdl.GPUBuffer,
	uvs:                ^sdl.GPUBuffer,
	indices:            ^sdl.GPUBuffer,
	SBO:                ^sdl.GPUBuffer,
	texture:            ^sdl.GPUTexture,
	sampler:            ^sdl.GPUSampler,
} = {}

cubeVertexBufferDescriptions := [?]sdl.GPUVertexBufferDescription {
	{slot = 0, instance_step_rate = 0, input_rate = .VERTEX, pitch = size_of(float3)},
	{slot = 1, instance_step_rate = 0, input_rate = .VERTEX, pitch = size_of(float2)},
}


cube_init :: proc() {
	R_cube.vertexShaderInfo = {
		UBOs = 2,
		SBOs = 1,
	}

	vertexShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "cube.vertex.spv"},
			allocator = context.temp_allocator,
		),
		R_cube.vertexShaderInfo,
	)

	R_cube.fragmentShaderInfo = {
		samplers = 1,
		UBOs     = 1,
	}
	fragmentShader := load_shader(
		filepath.join(
			{"resources", "shader-binaries", "cube.fragment.spv"},
			allocator = context.temp_allocator,
		),
		R_cube.fragmentShaderInfo,
	)

	cubeVertexAttributes := [?]sdl.GPUVertexAttribute {
		{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
		{buffer_slot = 1, format = .FLOAT2, location = 1, offset = 0},
	}
	R_cube.pipeline = sdl.CreateGPUGraphicsPipeline(
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
			rasterizer_state = {
				cull_mode = .BACK,
				fill_mode = .FILL,
				front_face = .COUNTER_CLOCKWISE,
			},
			vertex_input_state = {
				num_vertex_buffers = len(cubeVertexBufferDescriptions),
				vertex_buffer_descriptions = raw_data(cubeVertexBufferDescriptions[:]),
				num_vertex_attributes = len(cubeVertexAttributes),
				vertex_attributes = raw_data(cubeVertexAttributes[:]),
			},
			primitive_type = .TRIANGLELIST,
			vertex_shader = vertexShader,
			fragment_shader = fragmentShader,
		},
	)

	sdl_ensure(R_cube.pipeline != nil)

	sdl.ReleaseGPUShader(device, vertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)


	sdl.GetWindowSizeInPixels(window, &screenWidth, &screenHeight)

	R_cube.positions = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(cubePositions))},
	)
	sdl_ensure(R_cube.positions != nil)
	sdl.SetGPUBufferName(device, R_cube.positions, "positions")
	gpu_buffer_upload(&R_cube.positions, raw_data(&cubePositions), size_of(cubePositions))


	R_cube.uvs = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = size_of(cubeUV)},
	)
	sdl_ensure(R_cube.uvs != nil)
	sdl.SetGPUBufferName(device, R_cube.uvs, "uvs")
	gpu_buffer_upload(&R_cube.uvs, raw_data(&cubeUV), size_of(cubeUV))


	R_cube.indices = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = size_of(cubeIndices)},
	)
	sdl_ensure(R_cube.indices != nil)
	sdl.SetGPUBufferName(device, R_cube.indices, "indices")
	gpu_buffer_upload(&R_cube.indices, raw_data(&cubeIndices), size_of(cubeIndices))


	R_cube.SBO = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.GRAPHICS_STORAGE_READ}, size = size_of(cubes)},
	)
	sdl.SetGPUBufferName(device, R_cube.SBO, "cubeSBO")

	for x in 0 ..< GRID_X_LEN {
		for y in 0 ..< GRID_Y_LEN {
			for z in 0 ..< GRID_Z_LEN {

				worldPosition := float3 {
					f32(x) - GRID_X_LEN / 2,
					f32(y) - GRID_Y_LEN / 2,
					f32(z) - GRID_Z_LEN / 2,
				}

				frequency: f32 : 10
				amplitude: f32 : 10
				surfaceY: f32 = math.sin(f32(x) * frequency) * amplitude
				chosenIndex: CubeAtlasIndex = .Grass

				atlasIndex: float2 = ---

				if chosenIndex != .Air {
					column := i32(chosenIndex) % i32(tileRows)
					row := i32(chosenIndex) / i32(tileRows)
					atlasIndex = float2{f32(column), f32(row)}
				} else {
					atlasIndex = {-1, -1}
				}


				cubes[x * GRID_Y_LEN * GRID_Z_LEN + y * GRID_Z_LEN + z] = CubeInfo {
					worldPosition = worldPosition,
					atlasIndex    = u32(chosenIndex),
				}
			}
		}
	}
	gpu_buffer_upload(&R_cube.SBO, raw_data(&cubes), size_of(cubes))


	R_cube.texture = load_image(
		filepath.join({"resources", "images", "atlas.jpg"}, allocator = context.temp_allocator),
	)
	sdl_ensure(R_cube.texture != nil)


	R_cube.sampler = sdl.CreateGPUSampler(
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
	sdl_ensure(R_cube.sampler != nil)
}
cube_draw :: proc(cmdBuf: ^^sdl.GPUCommandBuffer, renderPass: ^^sdl.GPURenderPass) {
	assert(cmdBuf != nil && renderPass != nil)
	currVertexInfo: ShaderInfo = {}
	currFragmentInfo: ShaderInfo = {}


	assert(R_cube.pipeline != nil)
	sdl.BindGPUGraphicsPipeline(renderPass^, R_cube.pipeline)

	assert(R_cube.positions != nil)
	assert(R_cube.uvs != nil)
	assert(R_cube.SBO != nil)

	sdl.BindGPUVertexStorageBuffers(renderPass^, 0, &R_cube.SBO, 1)
	currVertexInfo.SBOs += 1


	view, proj := Camera_view_proj(&camera)

	viewProj := [2]matrix[4, 4]f32{view, proj}
	sdl.PushGPUVertexUniformData(cmdBuf^, 0, &viewProj, size_of(viewProj))
	currVertexInfo.UBOs += 1

	bufferBindings := [?]sdl.GPUBufferBinding {
		{buffer = R_cube.positions, offset = 0},
		{buffer = R_cube.uvs, offset = 0},
	}
	#assert(len(cubeVertexBufferDescriptions) == len(bufferBindings))

	atlasUbo: CubeAtlasUBO = {ATLAS_NUM_OF_TILES, ATLAS_TILE_SIZE}

	sdl.PushGPUVertexUniformData(cmdBuf^, 1, &atlasUbo, size_of(atlasUbo))
	currVertexInfo.UBOs += 1

	sdl.BindGPUVertexBuffers(renderPass^, 0, raw_data(&bufferBindings), len(bufferBindings))
	sdl.BindGPUIndexBuffer(renderPass^, {buffer = R_cube.indices, offset = 0}, ._16BIT)

	assert(R_cube.texture != nil)
	assert(R_cube.sampler != nil)

	sdl.BindGPUFragmentSamplers(
		renderPass^,
		0,
		raw_data(
			[]sdl.GPUTextureSamplerBinding{{texture = R_cube.texture, sampler = R_cube.sampler}},
		),
		1,
	)
	currFragmentInfo.UBOs += 1
	currFragmentInfo.samplers += 1

	assert(shader_infos_are_equal(currVertexInfo, R_cube.vertexShaderInfo))
	assert(shader_infos_are_equal(currFragmentInfo, R_cube.fragmentShaderInfo))

	sdl.DrawGPUIndexedPrimitives(
		renderPass^,
		len(cubeIndices),
		GRID_X_LEN * GRID_Y_LEN * GRID_Z_LEN,
		0,
		0,
		0,
	)
}
cube_deinit :: proc() {
	sdl.ReleaseGPUBuffer(device, R_cube.positions)
	sdl.ReleaseGPUBuffer(device, R_cube.uvs)
	sdl.ReleaseGPUBuffer(device, R_cube.indices)
	sdl.ReleaseGPUBuffer(device, R_cube.SBO)
	sdl.ReleaseGPUTexture(device, R_cube.texture)
	sdl.ReleaseGPUSampler(device, R_cube.sampler)
	sdl.ReleaseGPUGraphicsPipeline(device, R_cube.pipeline)
}
