class_name ZoneDirector
extends RefCounted
## Builds a zone's enemy camps and runs them. Camps sleep until the player
## comes within aggro range or any member is hit; the lure wakes every camp in
## its radius. The zone is cleared when every camp member is dead. Each level
## has more and bigger camps, generated from a fixed seed.

## A camp's last member died at `at`. last_camp is true for the zone's final camp.
signal camp_cleared(camp: int, at: Vector2, last_camp: bool)

## Golden angle, for packing camp members in a sunflower spiral.
const GOLDEN_ANGLE := 2.39996323
## Sunflower spacing factor: neighbours end up about 1.8x this far apart.
const SPIRAL_DENSITY := 0.54

var level := 0
var camp_centers: PackedVector2Array = []
var camp_alive: PackedInt32Array = []
var camp_awake: PackedByteArray = []
## Living camp members across the zone (enemies spawned outside camps don't count).
var alive_total := 0

var _config: ZoneConfig
var _swarm: SwarmManager
var _half_extent: float
var _rng := RandomNumberGenerator.new()


func _init(config: ZoneConfig, swarm: SwarmManager, half_extent: float) -> void:
	_config = config
	_swarm = swarm
	_half_extent = half_extent


## Clears the swarm and spawns this level's camps, all asleep.
func generate(p_level: int, player_start: Vector2) -> void:
	level = p_level
	_swarm.clear()
	camp_centers.clear()
	camp_alive.clear()
	camp_awake.clear()
	alive_total = 0
	_rng.seed = _config.zone_seed + level * 7919
	var wanted := mini(_config.camp_count + (level - 1) * _config.camps_per_level,
			_config.max_camps)
	var growth := pow(_config.camp_size_growth, level - 1)
	var limit := _half_extent - _config.edge_margin
	var safe_sq := _config.safe_start_radius * _config.safe_start_radius
	var spacing_sq := _config.camp_spacing * _config.camp_spacing
	for _attempt in _config.placement_attempts:
		if camp_centers.size() >= wanted:
			break
		var candidate := Vector2(_rng.randf_range(-limit, limit), _rng.randf_range(-limit, limit))
		if candidate.distance_squared_to(player_start) < safe_sq:
			continue
		var crowded := false
		for other in camp_centers:
			if candidate.distance_squared_to(other) < spacing_sq:
				crowded = true
				break
		if not crowded:
			camp_centers.append(candidate)
	var heavy_type := 1 if _swarm.config.enemy_types.size() > 1 else 0
	for camp in camp_centers.size():
		var size := roundi(_rng.randf_range(_config.camp_size_min, _config.camp_size_max) * growth)
		var spawned := 0
		var spiral := _config.member_spacing * SPIRAL_DENSITY
		for k in size:
			var offset := Vector2.from_angle(k * GOLDEN_ANGLE) * spiral * sqrt(k + 0.5)
			var type_id := heavy_type if _rng.randf() < _config.heavy_chance else 0
			if _swarm.spawn_at(camp_centers[camp] + offset, type_id, camp, false) >= 0:
				spawned += 1
		camp_alive.append(spawned)
		camp_awake.append(0)
		alive_total += spawned


## Wakes sleeping camps the player has come close to, or whose members were hit.
func tick(player_pos: Vector2) -> void:
	var alarm := _swarm.state.camp_alarm
	var aggro_sq := _config.aggro_radius * _config.aggro_radius
	for camp in camp_centers.size():
		if camp_awake[camp] != 0 or camp_alive[camp] == 0:
			continue
		if alarm[camp] != 0 or player_pos.distance_squared_to(camp_centers[camp]) <= aggro_sq:
			_wake(camp)


## Wakes every sleeping camp within radius of center. Returns how many woke.
func lure(center: Vector2, radius: float) -> int:
	var woken := 0
	var r_sq := radius * radius
	for camp in camp_centers.size():
		if camp_awake[camp] == 0 and camp_alive[camp] > 0 \
				and center.distance_squared_to(camp_centers[camp]) <= r_sq:
			_wake(camp)
			woken += 1
	return woken


## Counts this frame's deaths against their camps. Call after resolve_deaths().
func record_deaths(dead: int) -> void:
	var dead_camps := _swarm.state.dead_camps
	var dead_positions := _swarm.state.dead_positions
	for k in dead:
		var camp: int = dead_camps[k]
		if camp >= 0 and camp < camp_alive.size():
			camp_alive[camp] -= 1
			alive_total -= 1
			if camp_alive[camp] == 0:
				camp_cleared.emit(camp, dead_positions[k], alive_total <= 0)


func is_cleared() -> bool:
	return level > 0 and alive_total <= 0


func camps_left() -> int:
	var left := 0
	for alive in camp_alive:
		if alive > 0:
			left += 1
	return left


func _wake(camp: int) -> void:
	camp_awake[camp] = 1
	_swarm.state.camp_alarm[camp] = 0
	_swarm.wake_camp(camp)
