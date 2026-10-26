class_name SwarmRenderer
extends Node3D
## Draws the swarm with one MultiMeshInstance3D per enemy type.
## Each frame, live enemies are packed by type into that type's instance
## buffer and uploaded in one call. Per frame only the X and Z origin and the
## color change; the basis and height are written once at setup. Enemies show
## the flash color while their flash_until is in the future.

## A TRANSFORM_3D instance is a row-major 3x4 matrix followed by RGBA color.
const FLOATS_PER_INSTANCE := 16
const MESH_RADIAL_SEGMENTS := 10
const MESH_RINGS := 2

var _multimeshes: Array[MultiMesh] = []
var _buffers: Array[PackedFloat32Array] = []
var _colors: PackedColorArray = []
var _flash_color: Color


func setup(types: Array[EnemyType], capacity: int, flash_color: Color) -> void:
	_flash_color = flash_color
	for t in types:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = make_enemy_mesh(t)
		mm.instance_count = capacity
		var buffer := _make_buffer(capacity, t.body_height * 0.5, t.color)
		mm.buffer = buffer
		mm.visible_instance_count = 0

		var instance := MultiMeshInstance3D.new()
		instance.name = t.display_name
		instance.multimesh = mm
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if t.cast_shadow \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

		_multimeshes.append(mm)
		_buffers.append(buffer)
		_colors.append(t.color)


func draw(state: SwarmState, now: float) -> void:
	var count := state.count
	var positions := state.positions
	var type_ids := state.type_ids
	var flash_until := state.flash_until
	var flash := _flash_color
	for t in _multimeshes.size():
		var buffer: PackedFloat32Array = _buffers[t]
		var base: Color = _colors[t]
		var n := 0
		for i in count:
			if type_ids[i] != t:
				continue
			var p: Vector2 = positions[i]
			var c: Color = flash if flash_until[i] > now else base
			var b := n * FLOATS_PER_INSTANCE
			buffer[b + 3] = p.x
			buffer[b + 11] = p.y
			buffer[b + 12] = c.r
			buffer[b + 13] = c.g
			buffer[b + 14] = c.b
			n += 1
		var mm := _multimeshes[t]
		mm.buffer = buffer
		mm.visible_instance_count = n


## The capsule used for an enemy type, colored per instance. Shared with CorpseSystem.
static func make_enemy_mesh(t: EnemyType) -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = t.body_radius
	mesh.height = maxf(t.body_height, t.body_radius * 2.0)
	mesh.radial_segments = MESH_RADIAL_SEGMENTS
	mesh.rings = MESH_RINGS
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	mesh.material = material
	return mesh


func _make_buffer(capacity: int, height: float, color: Color) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(capacity * FLOATS_PER_INSTANCE)
	buffer.fill(0.0)
	for k in capacity:
		var b := k * FLOATS_PER_INSTANCE
		buffer[b] = 1.0
		buffer[b + 5] = 1.0
		buffer[b + 7] = height
		buffer[b + 10] = 1.0
		buffer[b + 12] = color.r
		buffer[b + 13] = color.g
		buffer[b + 14] = color.b
		buffer[b + 15] = color.a
	return buffer
