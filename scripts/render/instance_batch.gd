class_name InstanceBatch
extends MultiMeshInstance3D
## A MultiMesh with a preallocated buffer for pooled things drawn as scaled,
## colored instances (bolts, effects). Each frame: begin(), add() per
## instance, then commit() to upload everything in one call.

## Row-major 3x4 transform followed by RGBA color.
const FLOATS_PER_INSTANCE := 16

var _buffer: PackedFloat32Array
var _capacity := 0
var _count := 0
var _committed_count := 0


func setup(mesh: Mesh, capacity: int) -> void:
	_capacity = capacity
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	_buffer.resize(capacity * FLOATS_PER_INSTANCE)
	_buffer.fill(0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func begin() -> void:
	_count = 0


## Adds one instance with an axis-aligned scale. Ignored when full.
func add(pos: Vector3, scale_xyz: Vector3, color: Color) -> void:
	if _count >= _capacity:
		return
	var b := _count * FLOATS_PER_INSTANCE
	_buffer[b] = scale_xyz.x
	_buffer[b + 3] = pos.x
	_buffer[b + 5] = scale_xyz.y
	_buffer[b + 7] = pos.y
	_buffer[b + 10] = scale_xyz.z
	_buffer[b + 11] = pos.z
	_buffer[b + 12] = color.r
	_buffer[b + 13] = color.g
	_buffer[b + 14] = color.b
	_buffer[b + 15] = color.a
	_count += 1


func commit() -> void:
	# Nothing to show and nothing shown: skip the upload.
	if _count == 0 and _committed_count == 0:
		return
	multimesh.buffer = _buffer
	multimesh.visible_instance_count = _count
	_committed_count = _count


func count() -> int:
	return _count
