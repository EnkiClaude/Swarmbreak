class_name Player
extends Node3D
## Twin-stick player: left stick moves relative to the camera, right stick or
## mouse aims. With no aim input, the player faces where it is moving.

const AIM_MARKER_SIZE := Vector3(0.18, 0.18, 0.5)

@export var config: PlayerConfig

var velocity := Vector3.ZERO
## Unit vector on the XZ plane.
var aim_direction := Vector3.FORWARD

var _input := TwinStickInput.new()
var _camera_rig: CameraRig
var _half_extent: float


func _ready() -> void:
	_build_visuals()


func setup(camera_rig: CameraRig, arena_half_extent: float) -> void:
	_camera_rig = camera_rig
	_half_extent = arena_half_extent


func _unhandled_input(event: InputEvent) -> void:
	_input.observe(event)


func tick(delta: float) -> void:
	var yaw := _camera_rig.yaw()
	var move := _input.move_vector()
	var wish := _screen_to_world(move, yaw) * config.move_speed
	velocity = velocity.move_toward(wish, config.acceleration * delta)
	position += velocity * delta
	position.x = clampf(position.x, -_half_extent, _half_extent)
	position.z = clampf(position.z, -_half_extent, _half_extent)
	_update_aim(move, yaw)


## True while the right stick is held outside its deadzone.
func is_stick_aiming() -> bool:
	return _input.aim_source == TwinStickInput.AimSource.STICK \
			and _input.stick_aim() != Vector2.ZERO


func ground_position() -> Vector2:
	return Vector2(position.x, position.z)


func _update_aim(move: Vector2, yaw: float) -> void:
	var dir := Vector3.ZERO
	if _input.aim_source == TwinStickInput.AimSource.MOUSE:
		dir = _camera_rig.mouse_ground_point() - global_position
		dir.y = 0.0
	else:
		var stick := _input.stick_aim()
		dir = _screen_to_world(stick if stick != Vector2.ZERO else move, yaw)
	if dir.length_squared() < 0.0001:
		return
	aim_direction = dir.normalized()
	rotation.y = atan2(-aim_direction.x, -aim_direction.z)


## Maps a screen-space stick vector onto the ground so "up" is away from the camera.
func _screen_to_world(v: Vector2, yaw: float) -> Vector3:
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, yaw)


func _build_visuals() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = config.color

	var capsule := CapsuleMesh.new()
	capsule.radius = config.radius
	capsule.height = maxf(config.height, config.radius * 2.0)
	capsule.material = material
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = capsule
	body.position.y = capsule.height * 0.5
	add_child(body)

	var marker_mesh := BoxMesh.new()
	marker_mesh.size = AIM_MARKER_SIZE
	marker_mesh.material = material
	var marker := MeshInstance3D.new()
	marker.name = "AimMarker"
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, capsule.height * 0.6, -(config.radius + AIM_MARKER_SIZE.z * 0.5))
	add_child(marker)
