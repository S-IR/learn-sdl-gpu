package main
import sdl "vendor:sdl3"


screenWidth: i32 = 1600
screenHeight: i32 = 900

device: ^sdl.GPUDevice
window: ^sdl.Window


dt: f64


nearPlane: f32 : 0.2
farPlane: f32 : 160.0
camera := Camera_new(pos = {10, 0, 10})
