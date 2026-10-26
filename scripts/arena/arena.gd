class_name Arena
extends Node3D
## Builds the flat square arena floor and a low visual border from ArenaConfig.

const FLOOR_SHADER := preload("res://shaders/floor_grid.gdshader")
const BORDER_THICKNESS := 0.4

@export var config: ArenaConfig


func _ready() -> void:
	_build_floor()
	_build_border()


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * config.half_extent * 2.0
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	material.set_shader_parameter("base_color", config.floor_color)
	material.set_shader_parameter("line_color", config.grid_line_color)
	material.set_shader_parameter("cell_size", config.grid_cell_size)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	add_child(floor_mesh)


func _build_border() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = config.border_color
	var h := config.half_extent
	var length := h * 2.0 + BORDER_THICKNESS * 2.0
	var offset := h + BORDER_THICKNESS * 0.5
	var y := config.border_height * 0.5
	_add_wall("BorderNorth", Vector3(length, config.border_height, BORDER_THICKNESS), Vector3(0.0, y, -offset), material)
	_add_wall("BorderSouth", Vector3(length, config.border_height, BORDER_THICKNESS), Vector3(0.0, y, offset), material)
	_add_wall("BorderWest", Vector3(BORDER_THICKNESS, config.border_height, length), Vector3(-offset, y, 0.0), material)
	_add_wall("BorderEast", Vector3(BORDER_THICKNESS, config.border_height, length), Vector3(offset, y, 0.0), material)


func _add_wall(wall_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var wall := MeshInstance3D.new()
	wall.name = wall_name
	wall.mesh = box
	wall.position = at
	add_child(wall)
