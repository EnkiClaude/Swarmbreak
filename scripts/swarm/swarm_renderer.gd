class_name SwarmRenderer
extends Node3D
## Draws the swarm with one MultiMeshInstance3D per enemy type, each using
## its type's model (CharacterModels) and the enemy shader. Each frame, live
## enemies are packed by type into that type's instance buffer and uploaded
## in one call: the transform turned to face the enemy's heading, a white
## instance color, and custom data for the shader (how fast it walks, its
## hit flash, and whether a lure is hurrying it, which rims it in a faint
## glow). Types with no enemies this frame and last are skipped entirely.

## A TRANSFORM_3D instance is a row-major 3x4 matrix, then RGBA color, then
## custom RGBA. The color stays white: an explicit color keeps both renderers
## reading the custom data where it belongs.
const FLOATS_PER_INSTANCE := 20
const ENEMY_SHADER := preload("res://shaders/enemy.gdshader")

var _multimeshes: Array[MultiMesh] = []
var _buffers: Array[PackedFloat32Array] = []
## 1 / max_speed squared per type: walk amount from speed without a sqrt.
var _inv_speed_sq := PackedFloat32Array()
var _counts := PackedInt32Array()
var _shown := PackedInt32Array()


func setup(types: Array[EnemyType], capacity: int, flash_color: Color,
		lure_color: Color = Color(1.0, 0.8, 0.35), lure_glow: float = 0.6) -> void:
	for t in types:
		var material := ShaderMaterial.new()
		material.shader = ENEMY_SHADER
		material.set_shader_parameter("flash_color", flash_color)
		material.set_shader_parameter("lure_color", lure_color)
		material.set_shader_parameter("lure_glow", lure_glow)
		material.set_shader_parameter("cycle_speed", t.walk_cycle_speed)
		material.set_shader_parameter("stride_swing", t.walk_swing)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = CharacterModels.enemy(t, material)
		mm.instance_count = capacity
		var buffer := PackedFloat32Array()
		buffer.resize(capacity * FLOATS_PER_INSTANCE)
		buffer.fill(0.0)
		for k in capacity:
			var c := k * FLOATS_PER_INSTANCE
			for w in 4:
				buffer[c + 12 + w] = 1.0
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
		_inv_speed_sq.append(1.0 / maxf(t.max_speed * t.max_speed, 0.0001))
	_counts.resize(types.size())
	_shown.resize(types.size())
	_shown.fill(0)


func draw(state: SwarmState, now: float) -> void:
	var count := state.count
	var positions := state.positions
	var velocities := state.velocities
	var headings := state.headings
	var type_ids := state.type_ids
	var flash_until := state.flash_until
	var boost_until := state.boost_until
	var counts := _counts
	counts.fill(0)
	for i in count:
		counts[type_ids[i]] += 1
	for t in _multimeshes.size():
		if counts[t] == 0 and _shown[t] == 0:
			continue
		var buffer: PackedFloat32Array = _buffers[t]
		var inv_speed_sq: float = _inv_speed_sq[t]
		var n := 0
		for i in count:
			if type_ids[i] != t:
				continue
			var p: Vector2 = positions[i]
			var d: Vector2 = headings[i]
			var walk: float = minf(velocities[i].length_squared() * inv_speed_sq, 1.0)
			var b := n * FLOATS_PER_INSTANCE
			# Basis columns: x = (-dz, 0, dx), y = up, z = (-dx, 0, -dz), so the
			# model's -Z front looks along the heading.
			buffer[b] = -d.y
			buffer[b + 2] = -d.x
			buffer[b + 3] = p.x
			buffer[b + 5] = 1.0
			buffer[b + 8] = d.x
			buffer[b + 10] = -d.y
			buffer[b + 11] = p.y
			buffer[b + 16] = walk
			buffer[b + 17] = 1.0 if flash_until[i] > now else 0.0
			buffer[b + 18] = 1.0 if boost_until[i] > now else 0.0
			n += 1
		var mm := _multimeshes[t]
		mm.buffer = buffer
		mm.visible_instance_count = n
		_shown[t] = n


## The model for an enemy type with a lit vertex-color material (no rig
## animation). Corpses use it.
static func make_enemy_mesh(t: EnemyType) -> Mesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	return CharacterModels.enemy(t, material)
