package main
import "core:math"
import la "core:math/linalg"
import sdl "vendor:sdl3"
CAMERA_MOVEMENT :: enum {
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT,
}

DEFAULT_YAW :: -90.0
DEFAULT_PITCH :: 0

DEFAULT_MOVEMENT_SPEED :: 7.5
DEFAULT_FOV :: 45.0
DEFAULT_SENSITIVITY: f32 = 0.2


WORLD_UP: float3 : {0, 1, 0}

Camera :: struct {
	pos:               float3,
	front:             float3,
	up:                float3,
	right:             float3,
	yaw:               f32,
	pitch:             f32,
	movement_speed:    f32,
	mouse_sensitivity: f32,
	fov:               f32,
}

Camera_new :: proc(
	pos: float3 = {0.0, 0.0, 0},
	front: float3 = {0, 0, 1},
	up: float3 = {0.0, 1.0, 0.0},
	fov: f32 = DEFAULT_FOV,
) -> Camera {
	c := Camera {
		front             = front,
		movement_speed    = DEFAULT_MOVEMENT_SPEED,
		mouse_sensitivity = DEFAULT_SENSITIVITY,
		pos               = pos,
		yaw               = DEFAULT_YAW,
		pitch             = DEFAULT_PITCH,
		fov               = fov,
		up                = up,
	}
	Camera_rotate(&c)
	return c
}

Camera_process_keyboard_movement :: proc(c: ^Camera) {
	keys := sdl.GetKeyboardState(nil)

	movementVector: float3 = {}
	normalizedFront := la.normalize(float3{c.front.x, 0, c.front.z})
	normalizedRight := la.normalize(float3{c.right.x, 0, c.right.z})

	if keys[sdl.Scancode.W] != false {
		movementVector += normalizedFront
	}
	if keys[sdl.Scancode.S] != false {
		movementVector -= normalizedFront
	}
	if keys[sdl.Scancode.A] != false {
		movementVector -= normalizedRight
	}
	if keys[sdl.Scancode.D] != false {
		movementVector += normalizedRight
	}

	if keys[sdl.Scancode.SPACE] != false {
		movementVector += c.up
	}

	if keys[sdl.Scancode.X] != false {
		movementVector -= c.up
	}


	if la.length(movementVector) <= 0 do return

	delta := la.normalize(movementVector) * c.movement_speed * f32(dt)
	c.pos += float3{delta.x, delta.y, delta.z}

}

Camera_process_mouse_movement :: proc(c: ^Camera, received_xOffset, received_yOffset: f32) {
	xOffset := received_xOffset * c.mouse_sensitivity
	yOffset := -received_yOffset * c.mouse_sensitivity

	c.yaw += xOffset
	c.pitch += yOffset

	c.pitch = math.clamp(c.pitch, -89.0, 89.0)
	Camera_rotate(c)
}

Camera_view_proj :: proc(c: ^Camera) -> (view, proj: matrix[4, 4]f32) {
	view = la.matrix4_look_at_f32(c.pos, c.pos + c.front, c.up)

	proj = la.matrix4_perspective_f32(
		c.fov,
		f32(screenWidth) / f32(screenHeight),
		f32(nearPlane),
		f32(farPlane),
	)

	return view, proj

}

@(private)
Camera_rotate :: proc(c: ^Camera) {
	assert(!(math.is_nan(c.yaw) || math.is_nan(c.pitch)), "Invalid camera rotation")
	for coord in c.front {
		assert(!math.is_nan(coord))
	}
	for coord in c.right {
		assert(!math.is_nan(coord))
	}

	assert(!(math.is_nan(c.front.x) || math.is_nan(c.pitch)), "Invalid camera rotation")

	c.front.x = math.cos(c.yaw * la.RAD_PER_DEG) * math.cos(c.pitch * la.RAD_PER_DEG)
	c.front.y = math.sin(c.pitch * la.RAD_PER_DEG)
	c.front.z = math.sin(c.yaw * la.RAD_PER_DEG) * math.cos(c.pitch * la.RAD_PER_DEG)
	c.front = la.normalize(c.front)
	c.right = la.normalize(la.cross(c.front, WORLD_UP))
	c.up = la.normalize(la.cross(c.right, c.front))
}
