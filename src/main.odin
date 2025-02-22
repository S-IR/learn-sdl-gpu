package main
import "core:fmt"
import sdl "vendor:sdl3"

sdl_ensure :: proc(cond: bool, message: string = "") {
	msg := fmt.tprintf("%s:%s\n", message, sdl.GetError())
	ensure(cond, msg)
}
main :: proc() {
	fmt.println("hello world")

	width := 1280
	height := 720
	sdl_ensure(sdl.Init({.VIDEO}))
	window := sdl.CreateWindow("Learn SDL Gpu", i32(width), i32(height), {.RESIZABLE})
	sdl_ensure(window != nil)
	defer sdl.DestroyWindow(window)


	e: sdl.Event
	quit := false

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

	}
}
