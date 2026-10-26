class_name SwarmSteering
extends RefCounted
## The per-tick hot loop.
## Pass 1 builds each enemy's velocity from the flow field (or a straight chase
## near the player) plus separation from neighbours found in the spatial hash.
## Pass 2 integrates positions, keeps enemies out of the player's body and
## inside the arena.
##
## Packed arrays and members are pulled into locals because local access is
## far cheaper than member access in GDScript. A local packed array aliases the
## same storage, so writes land in SwarmState directly; the assignments at the
## end only make that explicit.
##
## Separation scans just the hash cells its radius overlaps and stops after
## max_neighbours, which bounds the cost per enemy inside dense packs.

const OVERLAP_EPSILON := 0.000001

var _state: SwarmState
var _grid: SpatialHash
var _flow: FlowField
var _types: SwarmTypeTable
var _direct_chase_distance: float
var _half_extent: float
var _max_neighbours: int


func _init(state: SwarmState, grid: SpatialHash, flow: FlowField, types: SwarmTypeTable,
		direct_chase_distance: float, half_extent: float, max_neighbours: int) -> void:
	_state = state
	_grid = grid
	_flow = flow
	_types = types
	_direct_chase_distance = direct_chase_distance
	_half_extent = half_extent
	_max_neighbours = max_neighbours


func step(player_pos: Vector2, player_radius: float, delta: float) -> void:
	var count := _state.count
	if count == 0:
		return
	var positions := _state.positions
	var velocities := _state.velocities
	var type_ids := _state.type_ids

	var max_speed := _types.max_speed
	var acceleration := _types.acceleration
	var body_radius := _types.body_radius
	var sep_radius := _types.separation_radius
	var sep_strength := _types.separation_strength

	var cell_start := _grid.cell_start
	var sorted_ids := _grid.sorted_ids
	var g_cols := _grid.cols
	var g_rows := _grid.rows
	var g_inv := _grid.inv_cell_size
	var g_origin := _grid.origin

	var flow_dirs := _flow.directions
	var f_cols := _flow.cols
	var f_rows := _flow.rows
	var f_inv := _flow.inv_cell_size
	var f_origin := _flow.origin

	var chase_sq := _direct_chase_distance * _direct_chase_distance
	var max_neighbours := _max_neighbours
	var g_last_col := g_cols - 1
	var g_last_row := g_rows - 1

	# Pass 1: velocities.
	for i in count:
		var p: Vector2 = positions[i]
		var t: int = type_ids[i]

		var to_player: Vector2 = player_pos - p
		var seek: Vector2
		if to_player.length_squared() < chase_sq:
			seek = to_player.normalized()
		else:
			var fx: int = clampi(int((p.x - f_origin.x) * f_inv), 0, f_cols - 1)
			var fz: int = clampi(int((p.y - f_origin.y) * f_inv), 0, f_rows - 1)
			seek = flow_dirs[fz * f_cols + fx]

		var r: float = sep_radius[t]
		var r_sq: float = r * r
		var sep := Vector2.ZERO
		var found := 0
		var x0: int = clampi(int((p.x - r - g_origin.x) * g_inv), 0, g_last_col)
		var x1: int = clampi(int((p.x + r - g_origin.x) * g_inv), 0, g_last_col)
		var z0: int = clampi(int((p.y - r - g_origin.y) * g_inv), 0, g_last_row)
		var z1: int = clampi(int((p.y + r - g_origin.y) * g_inv), 0, g_last_row)
		for z in range(z0, z1 + 1):
			if found >= max_neighbours:
				break
			var row: int = z * g_cols
			for x in range(x0, x1 + 1):
				if found >= max_neighbours:
					break
				var cell: int = row + x
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j: int = sorted_ids[k]
					if j == i:
						continue
					var away: Vector2 = p - positions[j]
					var d_sq: float = away.length_squared()
					if d_sq >= r_sq:
						continue
					found += 1
					if found > max_neighbours:
						break
					if d_sq < OVERLAP_EPSILON:
						# Exactly stacked: push the pair apart along opposite directions.
						var nudge := Vector2.from_angle(float(mini(i, j) * 7 + maxi(i, j)))
						sep += nudge if i < j else -nudge
						continue
					var d: float = sqrt(d_sq)
					sep += away * ((r - d) / (r * d))

		var top: float = max_speed[t]
		var desired: Vector2 = (seek * top + sep * sep_strength[t]).limit_length(top)
		var v: Vector2 = velocities[i]
		velocities[i] = v.move_toward(desired, acceleration[t] * delta)

	# Pass 2: positions.
	var h := _half_extent
	for i in count:
		var p: Vector2 = positions[i] + velocities[i] * delta
		var from_player: Vector2 = p - player_pos
		var min_d: float = player_radius + body_radius[type_ids[i]]
		var d_sq: float = from_player.length_squared()
		if d_sq < min_d * min_d and d_sq > OVERLAP_EPSILON:
			p = player_pos + from_player * (min_d / sqrt(d_sq))
		positions[i] = Vector2(clampf(p.x, -h, h), clampf(p.y, -h, h))

	_state.velocities = velocities
	_state.positions = positions
