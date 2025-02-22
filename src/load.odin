package main
import "core:fmt"
import "core:strings"
import sdl "vendor:sdl3"

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
