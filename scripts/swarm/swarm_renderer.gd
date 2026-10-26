class_name SwarmRenderer
extends Node3D
## Draws the swarm with one MultiMeshInstance3D per enemy type.
## Each frame, live enemies are packed by type into that type's instance
## buffer and uploaded in one call. Only the X and Z origin floats change per
## frame; the basis and height are written once at setup.

## A TRANSFORM_3D instance is a row-major 3x4 matrix.
const FLOATS_PER_INSTANCE := 12
const MESH_RADIAL_SEGMENTS := 10
const MESH_RINGS := 2

var _multimeshes: Array[MultiMesh] = []
var _buffers: Array[PackedFloat32Array] = []


func setup(types: Array[EnemyType], capacity: int) -> void:
	for t in types:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _make_mesh(t)
		mm.instance_count = capacity
		var buffer := _make_identity_buffer(capacity, t.body_height * 0.5)
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


func draw(state: SwarmState) -> void:
	var count := state.count
	var positions := state.positions
	var type_ids := state.type_ids
	for t in _multimeshes.size():
		var buffer: PackedFloat32Array = _buffers[t]
		# Drop the array's own reference so the writes below don't copy the buffer.
		_buffers[t] = PackedFloat32Array()
		var n := 0
		for i in count:
			if type_ids[i] != t:
				continue
			var p: Vector2 = positions[i]
			var b := n * FLOATS_PER_INSTANCE
			buffer[b + 3] = p.x
			buffer[b + 11] = p.y
			n += 1
		var mm := _multimeshes[t]
		mm.buffer = buffer
		mm.visible_instance_count = n
		_buffers[t] = buffer


func _make_mesh(t: EnemyType) -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = t.body_radius
	mesh.height = maxf(t.body_height, t.body_radius * 2.0)
	mesh.radial_segments = MESH_RADIAL_SEGMENTS
	mesh.rings = MESH_RINGS
	var material := StandardMaterial3D.new()
	material.albedo_color = t.color
	material.roughness = 0.8
	mesh.material = material
	return mesh


func _make_identity_buffer(capacity: int, height: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(capacity * FLOATS_PER_INSTANCE)
	buffer.fill(0.0)
	for k in capacity:
		var b := k * FLOATS_PER_INSTANCE
		buffer[b] = 1.0
		buffer[b + 5] = 1.0
		buffer[b + 7] = height
		buffer[b + 10] = 1.0
	return buffer
