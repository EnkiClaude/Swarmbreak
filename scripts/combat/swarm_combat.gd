class_name SwarmCombat
extends RefCounted
## Damage queries against the swarm, answered from the spatial hash.
## Must run after the hash is built and before SwarmState.remove_dead(), while
## enemy indices still match the hash. Killed enemies are left at health <= 0
## and skipped by later queries in the same frame.

const OVERLAP_EPSILON := 0.000001
## Enemies moved after the hash was built this frame, so queries look one
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
	var cell_start := _grid.cell_start
	var sorted_ids := _grid.sorted_ids
	var cols := _grid.cols
	var inv := _grid.inv_cell_size
	var origin := _grid.origin
	var x0 := clampi(int((center.x - radius - origin.x) * inv) - CELL_PADDING, 0, cols - 1)
	var x1 := clampi(int((center.x + radius - origin.x) * inv) + CELL_PADDING, 0, cols - 1)
	var z0 := clampi(int((center.y - radius - origin.y) * inv) - CELL_PADDING, 0, _grid.rows - 1)
	var z1 := clampi(int((center.y + radius - origin.y) * inv) + CELL_PADDING, 0, _grid.rows - 1)
	var r_sq := radius * radius
	var kills := 0

	for z in range(z0, z1 + 1):
		var row: int = z * cols
		for x in range(x0, x1 + 1):
			var cell: int = row + x
			for k in range(cell_start[cell], cell_start[cell + 1]):
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
	var cell_start := _grid.cell_start
	var sorted_ids := _grid.sorted_ids
	var cols := _grid.cols
	var inv := _grid.inv_cell_size
	var origin := _grid.origin
	var gx := clampi(int((point.x - origin.x) * inv), 0, cols - 1)
	var gz := clampi(int((point.y - origin.y) * inv), 0, _grid.rows - 1)
	var reach := 1 + CELL_PADDING
	for z in range(maxi(gz - reach, 0), mini(gz + reach + 1, _grid.rows)):
		var row: int = z * cols
		for x in range(maxi(gx - reach, 0), mini(gx + reach + 1, cols)):
			var cell: int = row + x
			for k in range(cell_start[cell], cell_start[cell + 1]):
				var i: int = sorted_ids[k]
				if health[i] <= 0.0:
					continue
				var touch: float = radius + body_radius[type_ids[i]]
				if (positions[i] - point).length_squared() < touch * touch:
					return i
	return -1
