class_name CameraRig
extends Node3D
## Angled orthographic camera that follows a target across the ground plane.
## The rig sits on the target and is rotated by yaw then pitch; the camera
## hangs back along the rig's +Z, looking at the rig origin.
##
## Shake uses a trauma value (0..1) that decays over time; the screen-space
## offset grows with trauma squared, so small hits barely move the camera and
## big ones jolt it.

@export var config: CameraConfig

var target: Node3D
## 0..1. Add to it with add_trauma().
var trauma := 0.0
var _camera: Camera3D
var _shake_time := 0.0


func _ready() -> void:
	rotation = Vector3(deg_to_rad(-config.pitch_degrees), deg_to_rad(config.yaw_degrees), 0.0)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = config.ortho_size
	_camera.near = 0.1
	_camera.far = config.distance * 3.0
	_camera.position = Vector3(0.0, 0.0, config.distance)
	add_child(_camera)
	_camera.make_current()


func follow(new_target: Node3D) -> void:
	target = new_target
	global_position = target.global_position


func tick(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-config.follow_sharpness * delta)
	global_position = global_position.lerp(target.global_position, weight)
	_tick_shake(delta)


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _tick_shake(delta: float) -> void:
	trauma = maxf(trauma - config.shake_decay * delta, 0.0)
	_shake_time += delta
	var strength := trauma * trauma * config.shake_max_offset
	var t := _shake_time * config.shake_frequency
	# Two incommensurate sines per axis read as noise without a noise texture.
	_camera.h_offset = strength * (sin(t * 1.0) * 0.6 + sin(t * 2.37) * 0.4)
	_camera.v_offset = strength * (sin(t * 1.31 + 1.7) * 0.6 + sin(t * 2.91) * 0.4)


func yaw() -> float:
	return rotation.y


## Where the mouse cursor's ray meets the ground plane (y = 0).
func mouse_ground_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return origin
	return origin - dir * (origin.y / dir.y)
