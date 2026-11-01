class_name CameraRig
extends Node3D
## Third-person perspective camera that follows the player from behind.
## The rig sits at the look point above the target and is rotated by yaw then
## pitch; the camera hangs back along the rig's +Z. The right stick (the aim
## actions, which touch drives too) turns and tilts it; on desktop, clicking
## the game captures the mouse and moving it does the same. The mouse wheel
## (or D-pad up/down) zooms out from the closest distance to max_distance,
## and the right-stick click (or Z, or the touch ZOOM button) steps through
## zoom levels. Near the arena edge the camera pulls in so it stays inside
## the walls.
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
var _yaw := 0.0
var _pitch := 0.0
var _limit := INF
## Distance the zoom is heading for, and where it is now.
var _zoom_goal := 0.0
var _zoom := 0.0


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = config.fov_degrees
	_camera.near = 0.1
	_camera.far = config.far
	add_child(_camera)
	_camera.make_current()
	reset_zoom()
	reset_view()


## Keeps the camera inside -half_extent..half_extent on X and Z.
func set_bounds(half_extent: float) -> void:
	_limit = half_extent - config.wall_margin


func follow(new_target: Node3D) -> void:
	target = new_target
	_place(1.0)


## Back to the starting angle, e.g. after going through a gate.
func reset_view() -> void:
	_yaw = deg_to_rad(config.yaw_degrees)
	_pitch = deg_to_rad(config.pitch_degrees)
	_apply_rotation()


func tick(delta: float) -> void:
	var look := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	turn(-look.x * deg_to_rad(config.turn_speed) * delta,
			look.y * deg_to_rad(config.tilt_speed) * delta)
	_zoom = lerpf(_zoom, _zoom_goal, 1.0 - exp(-config.zoom_sharpness * delta))
	if target != null:
		_place(1.0 - exp(-config.follow_sharpness * delta))
	_tick_shake(delta)


## Turns by yaw radians (positive turns left) and tilts by pitch radians
## (positive looks further down).
func turn(yaw_delta: float, pitch_delta: float) -> void:
	_yaw = wrapf(_yaw + yaw_delta, -PI, PI)
	_pitch = clampf(_pitch + pitch_delta, deg_to_rad(config.min_pitch_degrees),
			deg_to_rad(config.max_pitch_degrees))
	_apply_rotation()


## Back to the closest zoom, at once.
func reset_zoom() -> void:
	_zoom_goal = config.distance
	_zoom = config.distance


## Zooms out by steps (negative zooms in), between the closest distance and
## max_distance.
func zoom(steps: float) -> void:
	_zoom_goal = clampf(_zoom_goal + steps * config.zoom_step, config.distance,
			config.max_distance)


## Steps out through zoom_levels evenly spaced levels, back to the closest
## after the farthest.
func cycle_zoom() -> void:
	var span := config.max_distance - config.distance
	var step := span / maxi(config.zoom_levels - 1, 1)
	if _zoom_goal >= config.max_distance - 0.01:
		_zoom_goal = config.distance
	else:
		_zoom_goal = minf(config.distance + (floorf((_zoom_goal - config.distance) / step + 0.01)
				+ 1.0) * step, config.max_distance)


## The distance the zoom is heading for.
func zoom_distance() -> float:
	return _zoom_goal


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		zoom(-1.0)
	elif event.is_action_pressed("camera_zoom_out"):
		zoom(1.0)
	elif event.is_action_pressed("camera_zoom_cycle"):
		cycle_zoom()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).relative
		var s := deg_to_rad(config.mouse_sensitivity)
		turn(-motion.x * s, motion.y * s)
	elif event is InputEventMouseButton and event.is_pressed() \
			and (event as InputEventMouseButton).button_index <= MOUSE_BUTTON_MIDDLE \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Browsers only allow pointer lock in answer to a click.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		release_mouse()


func release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Radians around the vertical axis; 0 looks toward -Z.
func yaw() -> float:
	return _yaw


## Unit vector on the ground plane the camera looks along.
func forward() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


func camera() -> Camera3D:
	return _camera


func _apply_rotation() -> void:
	rotation = Vector3(-_pitch, _yaw, 0.0)


func _place(weight: float) -> void:
	var t := target.global_position
	var goal := Vector3(t.x, t.y + config.look_height, t.z)
	global_position = global_position.lerp(goal, weight)
	# Ground direction from the look point toward the camera, per meter of distance.
	var back := -forward() * cos(_pitch)
	_camera.position.z = clamped_distance(Vector2(global_position.x, global_position.z),
			Vector2(back.x, back.z), _zoom, _limit, config.min_distance)


## How far along dir (ground offset per meter of distance) the camera can sit
## from origin before leaving the square -limit..limit, capped at distance and
## never below min_distance.
static func clamped_distance(origin: Vector2, dir: Vector2, distance: float, limit: float,
		min_distance: float) -> float:
	var allowed := distance
	if dir.x > 0.0:
		allowed = minf(allowed, (limit - origin.x) / dir.x)
	elif dir.x < 0.0:
		allowed = minf(allowed, (-limit - origin.x) / dir.x)
	if dir.y > 0.0:
		allowed = minf(allowed, (limit - origin.y) / dir.y)
	elif dir.y < 0.0:
		allowed = minf(allowed, (-limit - origin.y) / dir.y)
	return maxf(allowed, min_distance)


func _tick_shake(delta: float) -> void:
	trauma = maxf(trauma - config.shake_decay * delta, 0.0)
	_shake_time += delta
	var strength := trauma * trauma * config.shake_max_offset
	var t := _shake_time * config.shake_frequency
	# Two incommensurate sines per axis read as noise without a noise texture.
	_camera.h_offset = strength * (sin(t * 1.0) * 0.6 + sin(t * 2.37) * 0.4)
	_camera.v_offset = strength * (sin(t * 1.31 + 1.7) * 0.6 + sin(t * 2.91) * 0.4)
