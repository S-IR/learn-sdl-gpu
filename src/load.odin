package main
import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"
import stb "vendor:stb/image"

ShaderInfo :: struct {
	samplers, UBOs, SBOs, STOs: u32,
}
load_shader :: proc(shaderPath: string, info: ShaderInfo) -> ^sdl.GPUShader {
	stage: sdl.GPUShaderStage

	if strings.contains(shaderPath, ".vert") {
		stage = .VERTEX
	} else if strings.contains(shaderPath, ".frag") {
		stage = .FRAGMENT
	} else {
		panic(
			fmt.tprintf("Shader suffix is neither .vert or .frag, shader path is %s", shaderPath),
		)
	}

	format := sdl.GetGPUShaderFormats(device)
	entrypoint: cstring
	if format >= {.SPIRV} || format >= {.DXIL} {
		entrypoint = "main"
	} else {
		panic("unsupported backend shader format")
	}

	codeSize: uint
	code := sdl.LoadFile(strings.clone_to_cstring(shaderPath, context.temp_allocator), &codeSize)
	sdl_ensure(code != nil)

	return sdl.CreateGPUShader(
		device,
		sdl.GPUShaderCreateInfo {
			code = transmute([^]u8)(code),
			code_size = codeSize,
			entrypoint = entrypoint,
			format = format,
			stage = stage,
			num_samplers = info.samplers,
			num_uniform_buffers = info.UBOs,
			num_storage_buffers = info.SBOs,
			num_storage_textures = info.STOs,
		},
	)

}
gpu_buffer_upload :: proc(buffer: ^^sdl.GPUBuffer, data: rawptr, size: uint) {
	transferBuffer := sdl.CreateGPUTransferBuffer(device, {usage = .UPLOAD, size = u32(size)})
	defer sdl.ReleaseGPUTransferBuffer(device, transferBuffer)

	transferData := sdl.MapGPUTransferBuffer(device, transferBuffer, true)
	sdl.memcpy(transferData, data, size)
	sdl.UnmapGPUTransferBuffer(device, transferBuffer)

	uploadCmdBuf := sdl.AcquireGPUCommandBuffer(device)
	copyPass := sdl.BeginGPUCopyPass(uploadCmdBuf)
	sdl.UploadToGPUBuffer(
		copyPass,
		{transfer_buffer = transferBuffer, offset = 0},
		{buffer = buffer^, offset = 0, size = u32(size)},
		false,
	)

	sdl.EndGPUCopyPass(copyPass)
	sdl_ensure(sdl.SubmitGPUCommandBuffer(uploadCmdBuf) != false)
}
load_image :: proc(path: string) -> ^sdl.GPUTexture {
	width, height, channels: i32
	DESIRED_CHANNELS :: 4
	data := stb.load(
		strings.clone_to_cstring(path, context.temp_allocator),
		&width,
		&height,
		&channels,
		DESIRED_CHANNELS, // Force RGBA
	)
	if data == nil {
		panic(fmt.tprintf("Failed to load image: %v", path))
	}
	defer stb.image_free(data)

	texture := sdl.CreateGPUTexture(
		device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			format = .R8G8B8A8_UNORM,
			width = u32(width),
			height = u32(height),
			layer_count_or_depth = 1,
			num_levels = 3,
			usage = {.SAMPLER, .COLOR_TARGET},
		},
	)

	image_size := width * height * DESIRED_CHANNELS
	transferBuffer := sdl.CreateGPUTransferBuffer(
		device,
		sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(image_size)},
	)
	defer sdl.ReleaseGPUTransferBuffer(device, transferBuffer)

	// Map the transfer buffer and copy the image data
	buffer_data := sdl.MapGPUTransferBuffer(device, transferBuffer, true)
	sdl.memcpy(buffer_data, data, uint(image_size))
	sdl.UnmapGPUTransferBuffer(device, transferBuffer)

	// Upload the data to the texture
	cmdBuf := sdl.AcquireGPUCommandBuffer(device)
	copyPass := sdl.BeginGPUCopyPass(cmdBuf)

	sdl.UploadToGPUTexture(
		copyPass,
		{offset = 0, transfer_buffer = transferBuffer},
		{texture = texture, w = u32(width), h = u32(height), d = 1},
		true,
	)

	sdl.EndGPUCopyPass(copyPass)
	sdl.GenerateMipmapsForGPUTexture(cmdBuf, texture)

	sdl_ensure(sdl.SubmitGPUCommandBuffer(cmdBuf) != false)

	return texture
}
