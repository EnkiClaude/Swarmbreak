class_name SwarmCombat
extends RefCounted
## Damage queries against the swarm, answered from the spatial hash.
## Must run after the hash is built and before SwarmState.remove_dead(), while
## enemy indices still match the hash. Killed enemies are left at health <= 0
## and skipped by later queries in the same frame. Hitting a sleeping enemy
## wakes it and raises its camp's alarm, so the whole camp wakes.

const OVERLAP_EPSILON := 0.000001
## Enemies moved after the hash was built this frame, so queries reach one
## extra cell out to catch any that crossed a cell edge.
const CELL_PADDING := 1
## Most hits damage_circle() remembers per call, for damage numbers and strikes.
const HIT_SAMPLES := 12

## A random sample of the last damage_circle() call's hits: where each enemy
## stood and how much damage it took. hit_sample_count of them are valid.
var hit_positions := PackedVector2Array()
var hit_amounts := PackedFloat32Array()
var hit_sample_count := 0
## How many enemies the last damage_circle() call hit.
var hit_count := 0

var _state: SwarmState
var _grid: SpatialHash
var _types: SwarmTypeTable
var _rng := RandomNumberGenerator.new()


func _init(state: SwarmState, grid: SpatialHash, types: SwarmTypeTable) -> void:
	_state = state
	_grid = grid
	_types = types
	hit_positions.resize(HIT_SAMPLES)
	hit_amounts.resize(HIT_SAMPLES)


## Damages and knocks back every live enemy whose center is within radius.
## Hit enemies flash until flash_until. Marked enemies (mark_until > now)
## take mark_bonus extra damage. Returns how many this call killed, and
## leaves a sample of the hits in hit_positions / hit_amounts (reservoir
## sampling, so a big pack's numbers spread over the whole pack).
func damage_circle(center: Vector2, radius: float, damage: float, knockback: float,
		flash_until: float, now: float = 0.0, mark_bonus: float = 0.0) -> int:
	var positions := _state.positions
	var velocities := _state.velocities
	var health := _state.health
	var flash := _state.flash_until
	var awake := _state.awake
	var camp_ids := _state.camp_ids
	var alarm := _state.camp_alarm
	var marks := _state.mark_until
	var type_ids := _state.type_ids
	var resist := _types.knockback_resist
	var marked_damage := damage * (1.0 + mark_bonus)
	var bucket_start := _grid.bucket_start
	var sorted_ids := _grid.sorted_ids
	var stamp := _grid.visit_stamp
	var mask := _grid.bucket_mask
	var visit := _grid.next_visit()
	var x0 := _grid.cell_coord(center.x - radius) - CELL_PADDING
	var x1 := _grid.cell_coord(center.x + radius) + CELL_PADDING
	var z0 := _grid.cell_coord(center.y - radius) - CELL_PADDING
	var z1 := _grid.cell_coord(center.y + radius) + CELL_PADDING
	var r_sq := radius * radius
	var kills := 0
	var hits := 0
	var sample_positions := hit_positions
	var sample_amounts := hit_amounts

	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			var b: int = SpatialHash.bucket_of_cell(cx, cz, mask)
			if stamp[b] == visit:
				continue
			stamp[b] = visit
			for k in range(bucket_start[b], bucket_start[b + 1]):
				var i: int = sorted_ids[k]
				var hp: float = health[i]
				if hp <= 0.0:
					continue
				var away: Vector2 = positions[i] - center
				var d_sq: float = away.length_squared()
				if d_sq > r_sq:
					continue
				var dealt: float = marked_damage if marks[i] > now else damage
				hp -= dealt
				health[i] = hp
				var slot: int = hits if hits < HIT_SAMPLES else _rng.randi() % (hits + 1)
				if slot < HIT_SAMPLES:
					sample_positions[slot] = positions[i]
					sample_amounts[slot] = dealt
				hits += 1
				flash[i] = flash_until
				if hp <= 0.0:
					kills += 1
				if d_sq > OVERLAP_EPSILON:
					var push: float = knockback * (1.0 - resist[type_ids[i]])
					velocities[i] += away * (push / sqrt(d_sq))
				if awake[i] == 0:
					awake[i] = 1
					var camp: int = camp_ids[i]
					if camp >= 0 and camp < alarm.size():
						alarm[camp] = 1

	_state.health = health
	_state.velocities = velocities
	_state.flash_until = flash
	hit_positions = sample_positions
	hit_amounts = sample_amounts
	hit_count = hits
	hit_sample_count = mini(hits, HIT_SAMPLES)
	return kills


## Aim assist: the direction from origin to the nearest live enemy within
## max_range whose direction is within the cone (dot with dir >= min_dot), or
## dir unchanged when there is none. dir must be a unit vector. Scans every
## enemy instead of the hash, so it works at any point in the frame; it runs
## once per bolt, not per enemy.
func assisted_aim(origin: Vector2, dir: Vector2, max_range: float, min_dot: float) -> Vector2:
	var positions := _state.positions
	var health := _state.health
	var best_sq := max_range * max_range
	var best := dir
	for i in _state.count:
		if health[i] <= 0.0:
			continue
		var to: Vector2 = positions[i] - origin
		var d_sq: float = to.length_squared()
		if d_sq >= best_sq or d_sq < 0.0001:
			continue
		var unit: Vector2 = to / sqrt(d_sq)
		if unit.dot(dir) < min_dot:
			continue
		best_sq = d_sq
		best = unit
	return best


## Index of a live enemy whose body touches the circle, or -1.
func first_hit(point: Vector2, radius: float) -> int:
	var positions := _state.positions
	var health := _state.health
	var type_ids := _state.type_ids
	var body_radius := _types.body_radius
	var bucket_start := _grid.bucket_start
	var sorted_ids := _grid.sorted_ids
	var stamp := _grid.visit_stamp
	var mask := _grid.bucket_mask
	var visit := _grid.next_visit()
	var gx := _grid.cell_coord(point.x)
	var gz := _grid.cell_coord(point.y)
	var reach := 1 + CELL_PADDING
	for cz in range(gz - reach, gz + reach + 1):
		for cx in range(gx - reach, gx + reach + 1):
			var b: int = SpatialHash.bucket_of_cell(cx, cz, mask)
			if stamp[b] == visit:
				continue
			stamp[b] = visit
			for k in range(bucket_start[b], bucket_start[b + 1]):
				var i: int = sorted_ids[k]
				if health[i] <= 0.0:
					continue
				var touch: float = radius + body_radius[type_ids[i]]
				if (positions[i] - point).length_squared() < touch * touch:
					return i
	return -1
