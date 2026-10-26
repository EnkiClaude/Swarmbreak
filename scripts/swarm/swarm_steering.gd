class_name SwarmSteering
extends RefCounted
## The per-tick hot loop.
## Pass 1 builds each awake enemy's velocity from the flow field (or a
## straight chase near the player) plus separation from neighbours found in
## the spatial hash. Sleeping camp members only bleed off knockback, so a
## sleeping camp costs almost nothing.
## Pass 2 integrates positions, keeps enemies out of the player's body and
## inside the arena, and totals the damage from enemies touching the player.
##
## Packed arrays and members are pulled into locals because local access is
## far cheaper than member access in GDScript. A local packed array aliases the
## same storage, so writes land in SwarmState directly; the assignments at the
## end only make that explicit.
##
## Separation scans just the hash cells its radius overlaps, visits each
## bucket once, and stops after max_neighbours, which bounds the cost per
## enemy inside dense packs.

const OVERLAP_EPSILON := 0.000001

## Damage per second from enemies touching the player in the last step().
var contact_dps := 0.0
## How many awake enemies touched the player in the last step().
var contact_count := 0

var _state: SwarmState
var _grid: SpatialHash
var _flow: FlowField
var _types: SwarmTypeTable
var _direct_chase_distance: float
var _half_extent: float
var _max_neighbours: int
var _max_attackers: int


func _init(state: SwarmState, grid: SpatialHash, flow: FlowField, types: SwarmTypeTable,
		direct_chase_distance: float, half_extent: float, max_neighbours: int,
		max_attackers: int = 1 << 30) -> void:
	_state = state
	_grid = grid
	_flow = flow
	_types = types
	_direct_chase_distance = direct_chase_distance
	_half_extent = half_extent
	_max_neighbours = max_neighbours
	_max_attackers = max_attackers


## now is swarm time (for lure boosts); boost_multiplier scales boosted speed.
func step(player_pos: Vector2, player_radius: float, delta: float, now: float = 0.0,
		boost_multiplier: float = 1.0) -> void:
	contact_dps = 0.0
	contact_count = 0
	var count := _state.count
	if count == 0:
		return
	var positions := _state.positions
	var velocities := _state.velocities
	var type_ids := _state.type_ids
	var awake := _state.awake
	var boost_until := _state.boost_until

	var max_speed := _types.max_speed
	var acceleration := _types.acceleration
	var body_radius := _types.body_radius
	var sep_radius := _types.separation_radius
	var sep_strength := _types.separation_strength
	var contact := _types.contact_dps
	var reach := _types.attack_reach

	var bucket_start := _grid.bucket_start
	var sorted_ids := _grid.sorted_ids
	var stamp := _grid.visit_stamp
	var mask := _grid.bucket_mask
	var g_inv := _grid.inv_cell_size
	var hash_x := SpatialHash.HASH_X
	var hash_z := SpatialHash.HASH_Z

	var flow_dirs := _flow.directions
	var f_cols := _flow.cols
	var f_rows := _flow.rows
	var f_inv := _flow.inv_cell_size
	var f_origin := _flow.origin

	var chase_sq := _direct_chase_distance * _direct_chase_distance
	var max_neighbours := _max_neighbours
	# Visit ids for this step: one per enemy, reserved up front.
	var visit := _grid.visit_id
	if visit + count >= 1 << 30:
		stamp.fill(0)
		visit = 0
	_grid.visit_id = visit + count

	# Pass 1: velocities.
	for i in count:
		var v: Vector2 = velocities[i]
		var t: int = type_ids[i]
		if awake[i] == 0:
			velocities[i] = v.move_toward(Vector2.ZERO, acceleration[t] * delta)
			continue
		var p: Vector2 = positions[i]

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
		visit += 1
		var x1: int = floori((p.x + r) * g_inv)
		var z1: int = floori((p.y + r) * g_inv)
		for cz in range(floori((p.y - r) * g_inv), z1 + 1):
			if found >= max_neighbours:
				break
			for cx in range(floori((p.x - r) * g_inv), x1 + 1):
				if found >= max_neighbours:
					break
				var b: int = ((cx * hash_x) ^ (cz * hash_z)) & mask
				if stamp[b] == visit:
					continue
				stamp[b] = visit
				for k in range(bucket_start[b], bucket_start[b + 1]):
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
		if boost_until[i] > now:
			top *= boost_multiplier
		var desired: Vector2 = (seek * top + sep * sep_strength[t]).limit_length(top)
		velocities[i] = v.move_toward(desired, acceleration[t] * delta)

	# Pass 2: positions and contact damage.
	var h := _half_extent
	var attackers := 0
	var dps := 0.0
	var max_attackers := _max_attackers
	for i in count:
		var t: int = type_ids[i]
		var p: Vector2 = positions[i] + velocities[i] * delta
		var from_player: Vector2 = p - player_pos
		var min_d: float = player_radius + body_radius[t]
		var d_sq: float = from_player.length_squared()
		if d_sq < min_d * min_d and d_sq > OVERLAP_EPSILON:
			p = player_pos + from_player * (min_d / sqrt(d_sq))
			d_sq = min_d * min_d
		if awake[i] != 0:
			var hit_d: float = min_d + reach[t]
			if d_sq <= hit_d * hit_d:
				attackers += 1
				if attackers <= max_attackers:
					dps += contact[t]
		positions[i] = Vector2(clampf(p.x, -h, h), clampf(p.y, -h, h))

	contact_count = attackers
	contact_dps = dps
	_state.velocities = velocities
	_state.positions = positions
