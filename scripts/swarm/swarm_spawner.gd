class_name SwarmSpawner
extends RefCounted
## Places new enemies in a ring around a point, clamped to the arena.

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Returns how many enemies were actually spawned (the pool may be full).
func spawn_ring(state: SwarmState, amount: int, center: Vector2, min_distance: float,
		max_distance: float, type_id: int, max_health: float, half_extent: float) -> int:
	var lo := Vector2(-half_extent, -half_extent)
	var hi := Vector2(half_extent, half_extent)
	var min_sq := min_distance * min_distance
	var max_sq := max_distance * max_distance
	var spawned := 0
	for _n in amount:
		# sqrt of a uniform squared radius spreads enemies evenly by area.
		var dist := sqrt(_rng.randf_range(min_sq, max_sq))
		var p := center + Vector2.from_angle(_rng.randf() * TAU) * dist
		if state.spawn(p.clamp(lo, hi), type_id, max_health) < 0:
			break
		spawned += 1
	return spawned
