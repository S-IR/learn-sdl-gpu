package main
import sdl "vendor:sdl3"


screenWidth: i32 = 1280
screenHeight: i32 = 720

device: ^sdl.GPUDevice
window: ^sdl.Window


dt: f64


nearPlane: f32 : 0.2
farPlane: f32 : 160.0
