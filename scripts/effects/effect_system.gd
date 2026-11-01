class_name EffectSystem
extends Node3D
## Pooled visual effects. Each registered EffectType gets its own pool and
## InstanceBatch. Instances grow from start_scale to end_scale and fade out.
## Lightning bolts are turned a different way per instance, so a storm of
## them doesn't look like copies.

const SPHERE_RADIAL_SEGMENTS := 10
const SPHERE_RINGS := 5
const RING_INNER_RADIUS := 0.85
const RING_SEGMENTS := 32
const RING_TUBE_SEGMENTS := 4
const COLUMN_SEGMENTS := 16
const LIGHTNING_KINKS := 7
const LIGHTNING_WIDTH := 0.22
## Golden angle: consecutive bolts get well-spread turns.
const TURN_PER_INSTANCE := 2.39996

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
		var turned := type.shape == EffectType.Shape.LIGHTNING
		batch.begin()
		for i in pool.count:
			var t: float = ages[i] / type.duration
			var s: float = lerpf(type.start_scale, type.end_scale, t) * sizes[i]
			var color := type.color
			color.a *= 1.0 - t
			if turned:
				var turn := Basis(Vector3.UP, positions[i].x * 3.1 + positions[i].z * 1.7)
				batch.add_basis(positions[i], turn.scaled(Vector3(s, s * type.flatten, s)), color)
			else:
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
	if type.additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if type.shape == EffectType.Shape.COLUMN or type.shape == EffectType.Shape.LIGHTNING:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if type.shape == EffectType.Shape.COLUMN:
		var column := CylinderMesh.new()
		column.top_radius = 1.0
		column.bottom_radius = 1.0
		column.height = 1.0
		column.radial_segments = COLUMN_SEGMENTS
		column.rings = 1
		column.cap_top = false
		column.cap_bottom = false
		column.material = material
		return _raised(column, material)
	if type.shape == EffectType.Shape.LIGHTNING:
		return _make_lightning(material)
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


## The mesh moved up so it rises from y = 0 to 1 instead of centering on 0.
static func _raised(mesh: PrimitiveMesh, material: Material) -> Mesh:
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	var arrays := tool.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in vertices.size():
		vertices[k] = vertices[k] + Vector3(0.0, 0.5, 0.0)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var raised := ArrayMesh.new()
	raised.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	raised.surface_set_material(0, material)
	return raised


## A jagged bolt from y = 0 to 1 as two crossed ribbons, so it reads from
## any side. The zigzag is fixed (seeded) and narrows toward the top.
static func _make_lightning(material: Material) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var points := PackedVector3Array()
	for k in LIGHTNING_KINKS + 1:
		var y := float(k) / LIGHTNING_KINKS
		var jitter := 0.0 if k == 0 or k == LIGHTNING_KINKS else 0.35
		points.append(Vector3(rng.randf_range(-jitter, jitter), y, rng.randf_range(-jitter, jitter)))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		for k in LIGHTNING_KINKS:
			var w0 := LIGHTNING_WIDTH * (1.0 - 0.6 * float(k) / LIGHTNING_KINKS)
			var w1 := LIGHTNING_WIDTH * (1.0 - 0.6 * float(k + 1) / LIGHTNING_KINKS)
			var a := points[k] - side * w0
			var b := points[k] + side * w0
			var c := points[k + 1] + side * w1
			var d := points[k + 1] - side * w1
			for v: Vector3 in [a, b, c, a, c, d]:
				tool.add_vertex(v)
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	return mesh
