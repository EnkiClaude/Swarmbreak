class_name CorpseSystem
extends Node3D
## Pooled flying corpses: instead of vanishing, killed enemies are flung by
## the blow that killed them, tumble, bounce and shrink away. One pool and
## InstanceBatch per enemy type, sharing that type's swarm mesh.

var _config: FeedbackConfig
var _pools: Array[CorpsePool] = []
var _batches: Array[InstanceBatch] = []
var _colors: PackedColorArray = []
var _rest_heights: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()


func setup(types: Array[EnemyType], config: FeedbackConfig) -> void:
	_config = config
	_rng.randomize()
	@warning_ignore("integer_division")
	var per_type := maxi(1, config.corpse_capacity / maxi(types.size(), 1))
	for t in types:
		var batch := InstanceBatch.new()
		batch.name = "Corpses_" + t.display_name
		batch.setup(SwarmRenderer.make_enemy_mesh(t), per_type)
		add_child(batch)
		_batches.append(batch)
		_pools.append(CorpsePool.new(per_type))
		_colors.append(t.color.darkened(config.corpse_darken))
		_rest_heights.append(t.body_radius)


## Launches a corpse at ground position pos with the enemy's dying velocity (XZ).
func spawn(type_id: int, pos: Vector2, dying_velocity: Vector2) -> void:
	var fling := dying_velocity * _config.corpse_fling_scale
	var up := _rng.randf_range(_config.corpse_up_speed_min, _config.corpse_up_speed_max)
	var axis := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3),
			_rng.randf_range(-1.0, 1.0))
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	_pools[type_id].spawn(Vector3(pos.x, _rest_heights[type_id] + 0.5, pos.y),
			Vector3(fling.x, up, fling.y), axis.normalized(),
			_rng.randf_range(-_config.corpse_spin_max, _config.corpse_spin_max))


func tick(delta: float) -> void:
	var lifetime := _config.corpse_lifetime
	var shrink_from := lifetime * _config.corpse_shrink_start
	for t in _pools.size():
		var pool := _pools[t]
		pool.advance(delta, _config.corpse_gravity, _config.corpse_bounce,
				_config.corpse_ground_friction, _rest_heights[t], lifetime)
		var batch := _batches[t]
		var color: Color = _colors[t]
		var positions := pool.positions
		var axes := pool.spin_axes
		var angles := pool.angles
		var ages := pool.ages
		batch.begin()
		for i in pool.count:
			var age: float = ages[i]
			var s := 1.0
			if age > shrink_from:
				s = 1.0 - (age - shrink_from) / (lifetime - shrink_from)
			var basis := Basis(axes[i], angles[i]).scaled(Vector3(s, s, s))
			batch.add_basis(positions[i], basis, color)
		batch.commit()


func active_count() -> int:
	var total := 0
	for pool in _pools:
		total += pool.count
	return total
