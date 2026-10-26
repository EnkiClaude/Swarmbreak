class_name EffectSystem
extends Node3D
## Pooled visual effects. Each registered EffectType gets its own pool and
## InstanceBatch. Instances grow from start_scale to end_scale and fade out.

const SPHERE_RADIAL_SEGMENTS := 10
const SPHERE_RINGS := 5
const RING_INNER_RADIUS := 0.85
const RING_SEGMENTS := 32
const RING_TUBE_SEGMENTS := 4

var _types: Array[EffectType] = []
var _pools: Array[EffectPool] = []
var _batches: Array[InstanceBatch] = []


## Returns the id to spawn this effect with, or -1 for null. Registering the
## same resource twice returns the same id.
func register(type: EffectType) -> int:
	if type == null:
		return -1
	var existing := _types.find(type)
	if existing >= 0:
		return existing
	var batch := InstanceBatch.new()
	batch.name = "Effect%d" % _types.size()
	batch.setup(_make_mesh(type), type.capacity)
	add_child(batch)
	_types.append(type)
	_pools.append(EffectPool.new(type.capacity))
	_batches.append(batch)
	return _types.size() - 1


## Spawns at ground position pos (the type's height is added). Size scales the effect.
func spawn(id: int, pos: Vector3, size: float) -> void:
	if id < 0:
		return
	_pools[id].spawn(Vector3(pos.x, pos.y + _types[id].height, pos.z), size)


func tick(delta: float) -> void:
	for id in _types.size():
		var type := _types[id]
		var pool := _pools[id]
		var batch := _batches[id]
		pool.advance(delta, type.duration)
		var positions := pool.positions
		var sizes := pool.sizes
		var ages := pool.ages
		batch.begin()
		for i in pool.count:
			var t: float = ages[i] / type.duration
			var s: float = lerpf(type.start_scale, type.end_scale, t) * sizes[i]
			var color := type.color
			color.a *= 1.0 - t
			batch.add(positions[i], Vector3(s, s * type.flatten, s), color)
		batch.commit()


func active_count() -> int:
	var total := 0
	for pool in _pools:
		total += pool.count
	return total


func _make_mesh(type: EffectType) -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if type.shape == EffectType.Shape.RING:
		var ring := TorusMesh.new()
		ring.inner_radius = RING_INNER_RADIUS
		ring.outer_radius = 1.0
		ring.rings = RING_SEGMENTS
		ring.ring_segments = RING_TUBE_SEGMENTS
		ring.material = material
		return ring
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = SPHERE_RADIAL_SEGMENTS
	sphere.rings = SPHERE_RINGS
	sphere.material = material
	return sphere
