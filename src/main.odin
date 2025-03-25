package main
import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:path/filepath"
import "core:time"
import sdl "vendor:sdl3"
sdl_ensure :: proc(cond: bool, message: string = "") {
	ensure(cond, fmt.tprintf("%s:%s\n", message, sdl.GetError()))
}


float2 :: [2]f32
float3 :: [3]f32
float4 :: [4]f32


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
	sdl_ensure(sdl.Init({.VIDEO}))
	window = sdl.CreateWindow("Learn SDL Gpu", i32(screenWidth), i32(screenHeight), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)
	sdl_ensure(sdl.SetWindowRelativeMouseMode(window, true))

	device = sdl.CreateGPUDevice({.SPIRV}, ODIN_DEBUG, nil)
	sdl_ensure(device != nil)
	defer sdl.DestroyGPUDevice(device)

	sdl_ensure(sdl.ClaimWindowForGPUDevice(device, window) != false)

	depthTexture := sdl.CreateGPUTexture(
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
	defer sdl.ReleaseGPUTexture(device, depthTexture)
	cube_init()
	defer cube_deinit()


	e: sdl.Event
	quit := false


	lastFrameTime := time.now()
	FPS :: 144
	frameTime := time.Duration(time.Second / FPS)

	currRotationAngle: f32 = 0
	ROTATION_SPEED :: 90

	prevScreenWidth := screenWidth
	prevScreenHeight := screenHeight


	free_all(context.temp_allocator)


	for !quit {

		defer free_all(context.temp_allocator)
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
				switch e.key.key {
				case sdl.K_F11:
					flags := sdl.GetWindowFlags(window)
					if .FULLSCREEN in flags {
						sdl.SetWindowFullscreen(window, false)
					} else {
						sdl.SetWindowFullscreen(window, true)
					}
				case sdl.K_ESCAPE:
					quit = true

				}

			case .WINDOW_RESIZED:
				screenWidth, screenHeight = e.window.data1, e.window.data2
			case .MOUSE_MOTION:
				Camera_process_mouse_movement(&camera, e.motion.xrel, e.motion.yrel)
			case:
				continue
			}
		}
		if prevScreenWidth != screenWidth || prevScreenHeight != screenHeight {
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
			prevScreenWidth = screenWidth
			prevScreenHeight = screenHeight
		}

		Camera_process_keyboard_movement(&camera)

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
		cube_draw(&cmdBuf, &renderPass)
		sdl.EndGPURenderPass(renderPass)

	}
}

shader_infos_are_equal :: proc(a: ShaderInfo, b: ShaderInfo) -> bool {
	return a.UBOs == b.UBOs && a.SBOs == b.SBOs && a.samplers == b.samplers && a.STOs == b.STOs
}
