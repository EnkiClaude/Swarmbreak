class_name FlowField
extends RefCounted
## Grid of unit vectors pointing toward a goal (the player).
## With no blocked cells, every cell points straight at the goal cell's center.
## Once cells are blocked, costs come from a chamfer distance transform with 1
## and sqrt(2) steps, and each cell's direction is the negative cost gradient,
## which routes around obstacles and reads smoother than stepping to the
## cheapest neighbour. The field only rebuilds when the goal enters a new cell.

const UNREACHED := 1.0e9
const DIAGONAL := 1.41421356
## Sweep pairs before giving up. Open ground settles in three; mazes need more.
const MAX_SWEEPS := 8

var cell_size: float
var inv_cell_size: float
var origin: Vector2
var cols: int
var rows: int
var directions: PackedVector2Array
## Nonzero marks a cell enemies cannot enter.
var blocked: PackedByteArray
var _cost: PackedFloat32Array
var _goal_cell: int = -1
var _blocked_count: int = 0


func _init(half_extent: float, p_cell_size: float) -> void:
	cell_size = p_cell_size
	inv_cell_size = 1.0 / p_cell_size
	cols = maxi(1, ceili(half_extent * 2.0 * inv_cell_size))
	rows = cols
	origin = Vector2(-half_extent, -half_extent)
	var n := cols * rows
	directions.resize(n)
	directions.fill(Vector2.ZERO)
	blocked.resize(n)
	blocked.fill(0)
	_cost.resize(n)


func cell_index(p: Vector2) -> int:
	var x := clampi(int((p.x - origin.x) * inv_cell_size), 0, cols - 1)
	var z := clampi(int((p.y - origin.y) * inv_cell_size), 0, rows - 1)
	return z * cols + x


## Marks a cell as impassable (or clears it). Forces a rebuild on the next update().
func set_blocked(x: int, z: int, is_blocked: bool) -> void:
	var i := z * cols + x
	var value := 1 if is_blocked else 0
	if blocked[i] == value:
		return
	blocked[i] = value
	_blocked_count += 1 if is_blocked else -1
	_goal_cell = -1


## Rebuilds the field if the goal moved into a new cell. Returns true if it did.
func update(goal: Vector2) -> bool:
	var goal_cell := cell_index(goal)
	if goal_cell == _goal_cell:
		return false
	_goal_cell = goal_cell
	if _blocked_count == 0:
		_point_straight_at(goal_cell)
	else:
		_compute_costs(goal_cell)
		_compute_directions()
	return true


func _point_straight_at(goal_cell: int) -> void:
	var dirs := directions
	var half := cell_size * 0.5
	var gx := goal_cell % cols
	@warning_ignore("integer_division")
	var gz := goal_cell / cols
	var target := origin + Vector2(gx * cell_size + half, gz * cell_size + half)
	for z in rows:
		var dz := target.y - (origin.y + z * cell_size + half)
		var row := z * cols
		for x in cols:
			dirs[row + x] = Vector2(target.x - (origin.x + x * cell_size + half), dz).normalized()


func _compute_costs(goal_cell: int) -> void:
	_cost.fill(UNREACHED)
	_cost[goal_cell] = 0.0
	for _sweep in MAX_SWEEPS:
		var changed := _sweep_forward()
		changed = _sweep_backward() or changed
		if not changed:
			break


func _sweep_forward() -> bool:
	var changed := false
	for z in rows:
		for x in cols:
			var i := z * cols + x
			if blocked[i] != 0:
				continue
			var best: float = _cost[i]
			if x > 0:
				best = minf(best, _cost[i - 1] + 1.0)
			if z > 0:
				best = minf(best, _cost[i - cols] + 1.0)
				if x > 0:
					best = minf(best, _cost[i - cols - 1] + DIAGONAL)
				if x < cols - 1:
					best = minf(best, _cost[i - cols + 1] + DIAGONAL)
			if best < _cost[i]:
				_cost[i] = best
				changed = true
	return changed


func _sweep_backward() -> bool:
	var changed := false
	for z in range(rows - 1, -1, -1):
		for x in range(cols - 1, -1, -1):
			var i := z * cols + x
			if blocked[i] != 0:
				continue
			var best: float = _cost[i]
			if x < cols - 1:
				best = minf(best, _cost[i + 1] + 1.0)
			if z < rows - 1:
				best = minf(best, _cost[i + cols] + 1.0)
				if x < cols - 1:
					best = minf(best, _cost[i + cols + 1] + DIAGONAL)
				if x > 0:
					best = minf(best, _cost[i + cols - 1] + DIAGONAL)
			if best < _cost[i]:
				_cost[i] = best
				changed = true
	return changed


func _compute_directions() -> void:
	var cost := _cost
	var dirs := directions
	var last_col := cols - 1
	var last_row := rows - 1
	# Neighbour lookups are inlined: function calls dominate this loop otherwise.
	# Out-of-bounds and unreachable neighbours count as flat ground.
	for z in rows:
		for x in cols:
			var i := z * cols + x
			var c: float = cost[i]
			if c >= UNREACHED:
				dirs[i] = Vector2.ZERO
				continue
			var left: float = cost[i - 1] if x > 0 else c
			var right: float = cost[i + 1] if x < last_col else c
			var up: float = cost[i - cols] if z > 0 else c
			var down: float = cost[i + cols] if z < last_row else c
			if left >= UNREACHED:
				left = c
			if right >= UNREACHED:
				right = c
			if up >= UNREACHED:
				up = c
			if down >= UNREACHED:
				down = c
			var downhill := Vector2(left - right, up - down)
			if downhill.length_squared() < 0.0001:
				downhill = _steepest_neighbour(x, z, c)
			dirs[i] = downhill.normalized()


## Out-of-bounds and unreachable neighbours count as flat ground.
func _neighbour_cost(x: int, z: int, fallback: float) -> float:
	if x < 0 or z < 0 or x >= cols or z >= rows:
		return fallback
	var c: float = _cost[z * cols + x]
	return fallback if c >= UNREACHED else c


## Breaks ties on saddles where the gradient cancels out.
func _steepest_neighbour(x: int, z: int, c: float) -> Vector2:
	var best := c
	var best_dir := Vector2.ZERO
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var n := _neighbour_cost(x + dx, z + dz, c)
			if n < best:
				best = n
				best_dir = Vector2(dx, dz)
	return best_dir
