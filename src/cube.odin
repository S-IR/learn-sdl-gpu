package main

import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"
TOTAL_CUBE_VERTICES :: 24

tileWidth: f32 : 2
tileHeight: f32 : 2
CubeAtlasIndex :: enum u8 {
	Dirt,
	Stone,
	Grass,
	DieHard,
	Air,
}

CubeAtlasUBO :: struct {
	tileSize: float2,
}


GRID_SIZE :: 5
CubeInfo :: struct {
	worldPosition: float3,
	_pad0:         f32,
	index:         float2,
	_pad1:         float2,
}


cubes := [GRID_SIZE * GRID_SIZE]CubeInfo{}
tileSize :: float2{1.0 / tileWidth, 1.0 / tileHeight}


cubePositions := [24]float3 {
	// front face
	{-0.5, -0.5, 0.5}, // Front bottom left  (0)
	{0.5, -0.5, 0.5}, // Front bottom right (1)
	{0.5, 0.5, 0.5}, // Front top right    (2)
	{-0.5, 0.5, 0.5}, // Front top left     (3)

	// back face
	{-0.5, -0.5, -0.5}, // Back bottom left   (4)
	{-0.5, 0.5, -0.5}, // Back top left      (5)
	{0.5, 0.5, -0.5}, // Back top right     (6)
	{0.5, -0.5, -0.5}, // Back bottom right  (7)

	// right face
	{0.5, -0.5, -0.5}, // Right bottom back  (8)
	{0.5, 0.5, -0.5}, // Right top back     (9)
	{0.5, 0.5, 0.5}, // Right top front    (10)
	{0.5, -0.5, 0.5}, // Right bottom front (11)

	// left face
	{-0.5, -0.5, 0.5}, // Left bottom front  (12)
	{-0.5, 0.5, 0.5}, // Left top front     (13)
	{-0.5, 0.5, -0.5}, // Left top back      (14)
	{-0.5, -0.5, -0.5}, // Left bottom back   (15)

	// top face
	{-0.5, 0.5, -0.5}, // Top back left      (16)
	{0.5, 0.5, -0.5}, // Top back right     (17)
	{0.5, 0.5, 0.5}, // Top front right    (18)
	{-0.5, 0.5, 0.5}, // Top front left     (19)
	{-0.5, -0.5, 0.5}, // Bottom front left  (20)
	{-0.5, -0.5, -0.5}, // Bottom back left   (21)
	{0.5, -0.5, -0.5}, // Bottom back right  (22)
	{0.5, -0.5, 0.5}, // Bottom front right (23)
}

cubeColors := [TOTAL_CUBE_VERTICES]float3 {
	// front face
	{0, 0, 0}, // Front bottom left  (0)
	{0, 0, 0}, // Front bottom right (1)
	{0, 0, 0}, // Front top right    (2)
	{0, 0, 0}, // Front top left     (3)

	// back face
	{1, 0, 0}, // Back bottom left   (4)
	{1, 0, 0}, // Back top left      (5)
	{1, 0, 0}, // Back top right     (6)
	{1, 0, 0}, // Back bottom right  (7)

	// right face
	{1, 1, 0}, // Right bottom back  (8)
	{1, 1, 0}, // Right top back     (9)
	{1, 1, 0}, // Right top front    (10)
	{1, 1, 0}, // Right bottom front (11)

	// left face
	{1, 0, 1}, // Left bottom front  (12)
	{1, 0, 1}, // Left top front     (13)
	{1, 0, 1}, // Left top back      (14)
	{1, 0, 1}, // Left bottom back   (15)

	// top face
	{1, .5, .5}, // Top back left      (16)
	{1, .5, .5}, // Top back right     (17)
	{1, .5, .5}, // Top front right    (18)
	{1, .5, .5}, // Top front left     (19)

	//bottom face
	{1, .8, .8}, // Bottom front left  (20)
	{1, .8, .8}, // Bottom back left   (21)
	{1, .8, .8}, // Bottom back right  (22)
	{1, .8, .8}, // Bottom front right (23)
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

cubeIndices := [36]u16 {
	// Front face 
	0,
	1,
	2,
	0,
	2,
	3,
	// Back face 
	4,
	5,
	6,
	4,
	6,
	7,
	// Right facet
	8,
	9,
	10,
	8,
	10,
	11,
	// Left face 
	12,
	13,
	14,
	12,
	14,
	15,
	// Top face
	16,
	17,
	18,
	16,
	18,
	19,
	// Bottom face 
	20,
	21,
	22,
	20,
	22,
	23,
}

R_cube: struct {
	vertexShaderInfo:   ShaderInfo,
	fragmentShaderInfo: ShaderInfo,
	pipeline:           ^sdl.GPUGraphicsPipeline,
	positions:          ^sdl.GPUBuffer,
	colors:             ^sdl.GPUBuffer,
	uvs:                ^sdl.GPUBuffer,
	indices:            ^sdl.GPUBuffer,
	SBO:                ^sdl.GPUBuffer,
	texture:            ^sdl.GPUTexture,
	sampler:            ^sdl.GPUSampler,
} = {}

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

	vertexBufferDescriptions := [?]sdl.GPUVertexBufferDescription {
		{slot = 0, instance_step_rate = 0, input_rate = .VERTEX, pitch = size_of(float3)},
		{slot = 1, instance_step_rate = 0, input_rate = .VERTEX, pitch = size_of(float2)},
	}
	vertexAttributes := [?]sdl.GPUVertexAttribute {
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
			vertex_input_state = {
				num_vertex_buffers = len(vertexBufferDescriptions),
				vertex_buffer_descriptions = raw_data(vertexBufferDescriptions[:]),
				num_vertex_attributes = len(vertexAttributes),
				vertex_attributes = raw_data(vertexAttributes[:]),
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

	R_cube.colors = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(size_of(cubeColors))},
	)
	sdl_ensure(R_cube.colors != nil)
	sdl.SetGPUBufferName(device, R_cube.colors, "colors")
	gpu_buffer_upload(&R_cube.colors, raw_data(&cubeColors), size_of(cubeColors))


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

	{
		for x in 0 ..< GRID_SIZE {
			for z in 0 ..< GRID_SIZE {
				chosenIndex: CubeAtlasIndex = rand.choice_enum(CubeAtlasIndex)
				atlasIndex: float2 = ---

				if chosenIndex != .Air {
					column := i32(chosenIndex) % i32(tileWidth)
					row := i32(chosenIndex) / i32(tileWidth)
					atlasIndex = float2{f32(column), f32(row)}
				} else {
					atlasIndex = {-1, -1}
				}


				cubes[x * GRID_SIZE + z] = CubeInfo {
					worldPosition = {f32(x) - GRID_SIZE / 2, -1, f32(z) - GRID_SIZE / 2},
					index         = atlasIndex,
				}
			}
		}
		gpu_buffer_upload(&R_cube.SBO, raw_data(&cubes), size_of(cubes))

	}


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

	atlasUbo: CubeAtlasUBO = {tileSize}

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

	sdl.DrawGPUIndexedPrimitives(renderPass^, len(cubeIndices), GRID_SIZE * GRID_SIZE, 0, 0, 0)
}
cube_deinit :: proc() {
	sdl.ReleaseGPUBuffer(device, R_cube.positions)
	sdl.ReleaseGPUBuffer(device, R_cube.colors)
	sdl.ReleaseGPUBuffer(device, R_cube.uvs)
	sdl.ReleaseGPUBuffer(device, R_cube.indices)
	sdl.ReleaseGPUBuffer(device, R_cube.SBO)
	sdl.ReleaseGPUTexture(device, R_cube.texture)
	sdl.ReleaseGPUSampler(device, R_cube.sampler)
	sdl.ReleaseGPUGraphicsPipeline(device, R_cube.pipeline)
}
