class_name ProjectileSystem
extends Node3D
## Pooled player bolts. A bolt flies straight and bursts when it touches an
## enemy or reaches the end of its life, damaging everything in burst_radius.
## Bolts leaving the arena vanish without bursting.

signal bolt_burst(at: Vector2)

const MESH_RADIAL_SEGMENTS := 8
const MESH_RINGS := 4

## Bolts fired since setup, for tests and stats.
var fired_total: int = 0
## Scales bolt burst damage (from player stats).
var damage_multiplier := 1.0

var _config: BoltConfig
var _pool: ProjectilePool
var _batch: InstanceBatch
var _effects: EffectSystem
var _burst_effect := -1
var _half_extent: float


func setup(config: BoltConfig, effects: EffectSystem, arena_half_extent: float) -> void:
	_config = config
	_effects = effects
	_half_extent = arena_half_extent
	_pool = ProjectilePool.new(config.capacity)
	_burst_effect = effects.register(config.burst_effect)
	_batch = InstanceBatch.new()
	_batch.name = "Bolts"
	_batch.setup(_make_mesh(), config.capacity)
	add_child(_batch)


## Fires one bolt from origin along direction (unit, XZ plane). False if the pool is full.
func fire(origin: Vector2, direction: Vector2) -> bool:
	if not _pool.spawn(origin + direction * _config.muzzle_offset, direction * _config.speed):
		return false
	fired_total += 1
	return true


## Moves bolts and resolves hits. Call between SwarmManager.simulate() and resolve_deaths().
func tick(delta: float, swarm: SwarmManager) -> void:
	_pool.advance(delta)
	var h := _half_extent
	for i in range(_pool.count - 1, -1, -1):
		var p: Vector2 = _pool.positions[i]
		if absf(p.x) > h or absf(p.y) > h:
			_pool.remove(i)
			continue
		if _pool.ages[i] >= _config.lifetime or swarm.first_hit(p, _config.hit_radius) >= 0:
			swarm.damage_circle(p, _config.burst_radius, _config.damage * damage_multiplier,
					_config.knockback)
			_effects.spawn(_burst_effect, Vector3(p.x, 0.0, p.y), _config.burst_radius)
			bolt_burst.emit(p)
			_pool.remove(i)
	_draw()


func active_count() -> int:
	return _pool.count


func _draw() -> void:
	var positions := _pool.positions
	var y := _config.height
	var scale_xyz := Vector3.ONE * _config.size
	_batch.begin()
	for i in _pool.count:
		var p: Vector2 = positions[i]
		_batch.add(Vector3(p.x, y, p.y), scale_xyz, _config.color)
	_batch.commit()


func _make_mesh() -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = MESH_RADIAL_SEGMENTS
	sphere.rings = MESH_RINGS
	sphere.material = material
	return sphere
