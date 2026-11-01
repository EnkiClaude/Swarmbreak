class_name Player
extends Node3D
## Third-person player: the left stick moves relative to the camera, and
## attacks aim where the camera looks. The player faces where it moves, and
## turns toward the aim while attacking or standing still.
## Dodge dashes along the move direction (or the aim, when standing still)
## and makes the player briefly invulnerable.

signal dashed

const HERO_SHADER := preload("res://shaders/hero.gdshader")

@export var config: PlayerConfig

var velocity := Vector3.ZERO
## Unit vector on the XZ plane: where the camera looks.
var aim_direction := Vector3.FORWARD
## Unit vector on the XZ plane the body faces.
var facing := Vector3.FORWARD

var vitals: PlayerVitals
var dash_cooldown: Cooldown
## Null until set_stats(); then movement and dodge read it.
var stats: PlayerStats

var _input := TwinStickInput.new()
var _dash_left := 0.0
var _dash_direction := Vector3.ZERO
var _camera_rig: CameraRig
var _half_extent: float
var _hero_material: ShaderMaterial
## Walk cycle angle and how far the casting arm is raised (0..1).
var _stride := 0.0
var _raise := 0.0


func _ready() -> void:
	vitals = PlayerVitals.new(config)
	dash_cooldown = Cooldown.new(config.dash_cooldown)
	_build_visuals()


func setup(camera_rig: CameraRig, arena_half_extent: float) -> void:
	_camera_rig = camera_rig
	_half_extent = arena_half_extent


## Keeps the player inside -half_extent..half_extent on X and Z.
func set_bounds(half_extent: float) -> void:
	_half_extent = half_extent


## Hooks up progression: vitals and movement then follow stat changes.
func set_stats(p_stats: PlayerStats) -> void:
	stats = p_stats
	vitals = PlayerVitals.new(config, stats)
	stats.changed.connect(_on_stats_changed)
	_on_stats_changed()


func _on_stats_changed() -> void:
	vitals.refresh_maxima()
	dash_cooldown.duration = config.dash_cooldown * (1.0 - stats.value(PlayerStat.Id.DODGE_COOLDOWN))


## Puts the player back at a spot, standing still.
func reset_to(at: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	_dash_left = 0.0
	dash_cooldown.remaining = 0.0


func is_dashing() -> bool:
	return _dash_left > 0.0


## now is swarm time, the clock invulnerability is measured against.
func tick(delta: float, now: float = 0.0) -> void:
	var yaw := _camera_rig.yaw()
	var move := _input.move_vector()
	dash_cooldown.tick(delta)
	if Input.is_action_just_pressed("dodge") and dash_cooldown.is_ready():
		_start_dash(move, yaw, now)
	if _dash_left > 0.0:
		_dash_left -= delta
		position += _dash_direction * (config.dash_distance / config.dash_duration) * delta
	else:
		var speed := config.move_speed
		if stats != null:
			speed *= stats.multiplier(PlayerStat.Id.MOVE_SPEED)
		var wish := _screen_to_world(move, yaw) * speed
		velocity = velocity.move_toward(wish, config.acceleration * delta)
		position += velocity * delta
	position.x = clampf(position.x, -_half_extent, _half_extent)
	position.z = clampf(position.z, -_half_extent, _half_extent)
	_update_aim(move, yaw)
	_animate(delta)


## Faces the aim right away, e.g. as an attack goes off.
func face_aim() -> void:
	_face(aim_direction)


func _start_dash(move: Vector2, yaw: float, now: float) -> void:
	var dir := _screen_to_world(move, yaw)
	if dir.length_squared() < 0.01:
		dir = aim_direction
	_dash_direction = dir.normalized()
	_dash_left = config.dash_duration
	velocity = _dash_direction * config.move_speed
	vitals.invulnerable_until = now + config.dash_duration + config.dash_grace
	dash_cooldown.trigger()
	dashed.emit()


func ground_position() -> Vector2:
	return Vector2(position.x, position.z)


func _update_aim(move: Vector2, yaw: float) -> void:
	aim_direction = _screen_to_world(Vector2.UP, yaw)
	var attacking := Input.is_action_pressed("attack_fire") or Input.is_action_pressed("attack_nova")
	if attacking or move == Vector2.ZERO or _dash_left > 0.0:
		_face(_dash_direction if _dash_left > 0.0 else aim_direction)
	else:
		_face(_screen_to_world(move, yaw))


func _face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	facing = dir.normalized()
	rotation.y = atan2(-facing.x, -facing.z)


## Maps a screen-space stick vector onto the ground so "up" is away from the camera.
func _screen_to_world(v: Vector2, yaw: float) -> Vector3:
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, yaw)


## Walks as fast as the player moves and raises the staff arm while attacking.
func _animate(delta: float) -> void:
	if _hero_material == null:
		return
	var speed := velocity.length() if _dash_left <= 0.0 else config.move_speed
	_stride += speed * config.stride_per_meter * delta
	var attacking := Input.is_action_pressed("attack_fire") or Input.is_action_pressed("attack_nova")
	_raise = move_toward(_raise, 1.0 if attacking else 0.0, config.raise_speed * delta)
	_hero_material.set_shader_parameter("walk", clampf(speed / config.move_speed, 0.0, 1.0))
	_hero_material.set_shader_parameter("phase", _stride)
	_hero_material.set_shader_parameter("raise", _raise)


func _build_visuals() -> void:
	_hero_material = ShaderMaterial.new()
	_hero_material.shader = HERO_SHADER
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = CharacterModels.hero(config.height, config.color, config.secondary_color,
			config.accent_color, _hero_material)
	add_child(body)
