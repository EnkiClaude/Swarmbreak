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

var _state: SwarmState
var _grid: SpatialHash
var _types: SwarmTypeTable


func _init(state: SwarmState, grid: SpatialHash, types: SwarmTypeTable) -> void:
	_state = state
	_grid = grid
	_types = types


## Damages and knocks back every live enemy whose center is within radius.
## Hit enemies flash until flash_until. Returns how many this call killed.
func damage_circle(center: Vector2, radius: float, damage: float, knockback: float,
		flash_until: float) -> int:
	var positions := _state.positions
	var velocities := _state.velocities
	var health := _state.health
	var flash := _state.flash_until
	var awake := _state.awake
	var camp_ids := _state.camp_ids
	var alarm := _state.camp_alarm
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
				hp -= damage
				health[i] = hp
				flash[i] = flash_until
				if hp <= 0.0:
					kills += 1
				if d_sq > OVERLAP_EPSILON:
					velocities[i] += away * (knockback / sqrt(d_sq))
				if awake[i] == 0:
					awake[i] = 1
					var camp: int = camp_ids[i]
					if camp >= 0 and camp < alarm.size():
						alarm[camp] = 1

	_state.health = health
	_state.velocities = velocities
	_state.flash_until = flash
	return kills


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
