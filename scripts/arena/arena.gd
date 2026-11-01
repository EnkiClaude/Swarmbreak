class_name Arena
extends Node3D
## Builds the zone's scenery from a ZoneTheme: the floor (reaching past the
## walls for outdoor zones), the four walls with trim bands, an optional
## ceiling, the props (ArenaProps) and the sky, fog and light
## (ArenaAtmosphere). apply_theme() rebuilds it all; call it at zone start,
## never during combat.

const FLOOR_SHADER := preload("res://shaders/zone_floor.gdshader")
const TRIM_HEIGHT := 0.5
const TRIM_DEPTH := 0.15

@export var config: ArenaConfig

## The theme applied last, or null.
var theme: ZoneTheme
var _scenery: Node3D


## seed makes prop placement repeatable per zone level.
func apply_theme(new_theme: ZoneTheme, environment: Environment, sun: DirectionalLight3D,
		seed_value: int = 0) -> void:
	theme = new_theme
	if _scenery != null:
		remove_child(_scenery)
		_scenery.queue_free()
	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	add_child(_scenery)
	_build_floor()
	_build_walls()
	if theme.ceiling_height > 0.0:
		_build_ceiling()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	ArenaProps.build(_scenery, theme, config.half_extent, config.wall_thickness, rng)
	if environment != null and sun != null:
		ArenaAtmosphere.apply(theme, environment, sun)


func _build_floor() -> void:
	var reach := config.half_extent + (theme.outside_reach if theme.ceiling_height <= 0.0 else 2.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * reach * 2.0
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	material.set_shader_parameter("pattern", int(theme.floor_pattern))
	material.set_shader_parameter("base_color", theme.floor_color)
	material.set_shader_parameter("alt_color", theme.floor_alt_color)
	material.set_shader_parameter("grout_color", theme.grout_color)
	material.set_shader_parameter("inlay_color", theme.inlay_color)
	material.set_shader_parameter("inlay_every", theme.inlay_every)
	material.set_shader_parameter("tile_size", theme.tile_size)
	material.set_shader_parameter("grout_width", theme.grout_width)
	material.set_shader_parameter("noise_amount", theme.floor_noise)
	material.set_shader_parameter("roughness_value", theme.floor_roughness)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scenery.add_child(floor_mesh)


func _build_walls() -> void:
	var wall := _material(theme.wall_color)
	var trim := _material(theme.wall_trim_color)
	var h := config.half_extent
	var t := config.wall_thickness
	var height := theme.wall_height
	var offset := h + t * 0.5
	var length := h * 2.0 + t * 2.0
	for side in 4:
		var along_x := side < 2
		var sign_value := -1.0 if side % 2 == 0 else 1.0
		var at := Vector3(0.0, 0.0, sign_value * offset) if along_x \
				else Vector3(sign_value * offset, 0.0, 0.0)
		var size := Vector3(length, height, t) if along_x else Vector3(t, height, length)
		var trim_size := size + (Vector3(0.0, 0.0, TRIM_DEPTH * 2.0) if along_x
				else Vector3(TRIM_DEPTH * 2.0, 0.0, 0.0))
		trim_size.y = minf(TRIM_HEIGHT, height * 0.4)
		_add_box(size, at + Vector3(0.0, height * 0.5, 0.0), wall)
		_add_box(trim_size, at + Vector3(0.0, trim_size.y * 0.5, 0.0), trim)
		_add_box(trim_size, at + Vector3(0.0, height - trim_size.y * 0.5, 0.0), trim)


func _build_ceiling() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (config.half_extent + config.wall_thickness) * 2.0
	plane.flip_faces = true
	plane.material = _material(theme.ceiling_color)
	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"
	ceiling.mesh = plane
	ceiling.position.y = theme.ceiling_height
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scenery.add_child(ceiling)


func _add_box(size: Vector3, at: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position = at
	_scenery.add_child(instance)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
