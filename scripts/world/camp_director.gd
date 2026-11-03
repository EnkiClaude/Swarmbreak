class_name CampDirector
extends RefCounted
## Runs the camps of the active space. A site's members exist in the swarm
## only while the player is near: sleeping sites within spawn_radius stream
## in, sleeping sites beyond despawn_radius stream out silently, so the swarm
## holds a few camps at a time however big the world is. A camp sleeps until
## the player comes within aggro range or any member is hit; the lure wakes
## every camp in its radius. A cleared camp comes back after its site's
## respawn time, never on top of the player unless that time is 0 (dungeons:
## the camp is back at once, asleep, and wakes if the player is near).
## Spawner sites never clear:
## while the player is within spawner_range they add one awake monster every
## spawn_interval until back at full population, so a build that survives
## the crowd can farm standing still.

## A camp's last member died at `at`.
signal camp_cleared(camp: int, at: Vector2, level: int, had_boss: bool)
## A spawner's monster died at `at`.
signal spawner_kill(camp: int, at: Vector2, level: int)

## Golden angle, for packing camp members in a sunflower spiral.
const GOLDEN_ANGLE := 2.39996323
## Sunflower spacing factor: neighbours end up about 1.8x this far apart.
const SPIRAL_DENSITY := 0.54
## Streaming checks run this often, in seconds of swarm time.
const STREAM_INTERVAL := 0.25
## With a boss in the middle, members start this many spiral steps out.
const BOSS_CLEARANCE := 6
## Spawner monsters appear within this distance of the spawner.
const SPAWNER_SCATTER := 3.0

## The active space's sites (CampSites); the HUD and tests read them.
var sites: CampSites
## True in dungeons: monsters spawn faster the higher their level.
var speed_by_level := false

var _config: WorldConfig
var _swarm: SwarmManager
var _bosses: BossSystem
var _boss_config: BossConfig
var _rng := RandomNumberGenerator.new()
var _next_stream := 0.0
## Members per site found in the swarm, refreshed by each streaming pass.
var _counted := PackedInt32Array()


func _init(config: WorldConfig, swarm: SwarmManager, bosses: BossSystem = null,
		boss_config: BossConfig = null) -> void:
	_config = config
	_swarm = swarm
	_bosses = bosses
	_boss_config = boss_config
	_rng.seed = config.world_seed


## Switches to another space's sites. The swarm must already be empty; the
## nearby sites stream in on the next tick.
func use_sites(new_sites: CampSites) -> void:
	if sites != null:
		sites.put_to_sleep()
	sites = new_sites
	sites.put_to_sleep()
	_counted.resize(sites.size())
	_next_stream = 0.0


## Wakes and refills camps, and streams sites in and out. Call after
## SwarmManager.resolve_deaths() and record_deaths().
func tick(player_pos: Vector2) -> void:
	if sites == null:
		return
	var now := _swarm.now()
	if now >= _next_stream:
		_next_stream = now + STREAM_INTERVAL
		_stream(player_pos, now)
	var alarm := _swarm.state.camp_alarm
	var aggro_sq := _config.aggro_radius * _config.aggro_radius
	var spawner_sq := _config.spawner_range * _config.spawner_range
	for s in sites.size():
		if sites.state[s] != CampSites.State.SPAWNED:
			continue
		var d_sq := player_pos.distance_squared_to(sites.centers[s])
		if sites.is_spawner[s] != 0:
			if sites.alive[s] < sites.sizes[s] and now >= sites.timer[s] and d_sq <= spawner_sq:
				_spawn_member(s, true, sites.centers[s] + Vector2.from_angle(_rng.randf() * TAU)
						* _rng.randf_range(0.5, SPAWNER_SCATTER))
				sites.timer[s] = now + sites.spawn_interval[s]
			continue
		if sites.awake[s] == 0 and (alarm[s] != 0 or d_sq <= aggro_sq):
			_wake(s)
		# A thinned-out camp gets its members back one by one.
		if sites.refill_time[s] > 0.0 and sites.alive[s] < sites.sizes[s] \
				and now >= sites.timer[s]:
			var spread := _config.member_spacing * SPIRAL_DENSITY * sqrt(float(sites.sizes[s]))
			var at := sites.centers[s] + Vector2.from_angle(_rng.randf() * TAU) \
					* _rng.randf() * spread
			if _spawn_member(s, sites.awake[s] != 0, at) >= 0 and sites.awake[s] == 0:
				sites.alive[s] += 1
			sites.timer[s] = now + sites.refill_time[s]


## Wakes every sleeping camp within radius of center. Returns how many woke.
func lure(center: Vector2, radius: float) -> int:
	if sites == null:
		return 0
	var woken := 0
	var r_sq := radius * radius
	for s in sites.size():
		if sites.state[s] == CampSites.State.SPAWNED and sites.awake[s] == 0 \
				and center.distance_squared_to(sites.centers[s]) <= r_sq:
			_wake(s)
			woken += 1
	return woken


## Counts this frame's deaths against their sites. Call after resolve_deaths().
func record_deaths(dead: int) -> void:
	if sites == null:
		return
	var dead_camps := _swarm.state.dead_camps
	var dead_positions := _swarm.state.dead_positions
	var now := _swarm.now()
	for k in dead:
		var s: int = dead_camps[k]
		if s < 0 or s >= sites.size() or sites.state[s] != CampSites.State.SPAWNED:
			continue
		sites.alive[s] -= 1
		if sites.is_spawner[s] != 0:
			spawner_kill.emit(s, dead_positions[k], sites.levels[s])
		elif sites.alive[s] > 0:
			# Start the refill clock on the first loss.
			if sites.timer[s] < now:
				sites.timer[s] = now + sites.refill_time[s]
		else:
			sites.alive[s] = 0
			sites.state[s] = CampSites.State.CLEARED
			sites.awake[s] = 0
			sites.timer[s] = now + sites.respawn_time[s]
			camp_cleared.emit(s, dead_positions[k], sites.levels[s], sites.has_boss[s] != 0)


## Sites still holding monsters (dormant or in the swarm).
func camps_left() -> int:
	if sites == null:
		return 0
	var left := 0
	for s in sites.size():
		if sites.state[s] != CampSites.State.CLEARED:
			left += 1
	return left


## Health multiplier for monsters of a camp level.
func health_multiplier(level: int) -> float:
	return 1.0 + _config.health_growth * (level - 1)


## Speed multiplier for a monster of a level: 1 in the open world; in
## dungeons (speed_by_level) a little faster per level, up to a cap.
func speed_multiplier(level: int) -> float:
	if not speed_by_level:
		return 1.0
	return minf(1.0 + _config.dungeon_speed_per_level * (level - 1), _config.dungeon_speed_max)


func _stream(player_pos: Vector2, now: float) -> void:
	_counted.fill(0)
	var camp_ids := _swarm.state.camp_ids
	for i in _swarm.state.count:
		var camp: int = camp_ids[i]
		if camp >= 0 and camp < _counted.size():
			_counted[camp] += 1
	var spawn_sq := _config.spawn_radius * _config.spawn_radius
	var despawn_sq := _config.despawn_radius * _config.despawn_radius
	var respawn_sq := _config.respawn_min_distance * _config.respawn_min_distance
	var spawner_out_sq := 4.0 * _config.spawner_range * _config.spawner_range
	for s in sites.size():
		var d_sq := player_pos.distance_squared_to(sites.centers[s])
		match sites.state[s]:
			CampSites.State.CLEARED:
				var instant := sites.respawn_time[s] <= 0.0
				if now >= sites.timer[s] and (instant or d_sq >= respawn_sq):
					sites.make_dormant(s)
					if d_sq <= spawn_sq:
						_spawn_site(s, now)
			CampSites.State.DORMANT:
				if d_sq <= spawn_sq:
					_spawn_site(s, now)
			CampSites.State.SPAWNED:
				if sites.is_spawner[s] != 0:
					sites.alive[s] = _counted[s]
					if d_sq > spawner_out_sq:
						_despawn_site(s)
				elif _counted[s] == 0:
					# Its members vanished without dying (the swarm was cleared).
					sites.make_dormant(s)
				elif d_sq > despawn_sq and sites.awake[s] == 0:
					_despawn_site(s)


func _spawn_site(s: int, now: float) -> void:
	sites.state[s] = CampSites.State.SPAWNED
	sites.awake[s] = 0
	if sites.is_spawner[s] != 0:
		# Spawners fill up one monster at a time, all awake.
		sites.alive[s] = 0
		sites.awake[s] = 1
		sites.timer[s] = now
		return
	var spawned := 0
	var center := sites.centers[s]
	var first := 0
	if sites.has_boss[s] != 0 and _spawn_boss(s):
		spawned += 1
		first = BOSS_CLEARANCE
	var spiral := _config.member_spacing * SPIRAL_DENSITY
	for k in range(first, first + sites.sizes[s]):
		var offset := Vector2.from_angle(k * GOLDEN_ANGLE) * spiral * sqrt(k + 0.5)
		if _spawn_member(s, false, center + offset) >= 0:
			spawned += 1
	sites.alive[s] = spawned


## Spawns one monster of site s (heavy by the site's chance). Returns its index.
func _spawn_member(s: int, is_awake: bool, at: Vector2) -> int:
	var last := _swarm.config.enemy_types.size() - 1
	var type_id := sites.heavy_type[s] if _rng.randf() < sites.heavy_chance[s] \
			else sites.light_type[s]
	type_id = clampi(type_id, 0, last)
	var i := _swarm.spawn_at(at, type_id, s, is_awake)
	if i >= 0:
		_swarm.state.health[i] *= health_multiplier(sites.levels[s])
		_swarm.state.speed_scale[i] = speed_multiplier(sites.levels[s])
		if is_awake:
			sites.alive[s] += 1
	return i


func _spawn_boss(s: int) -> bool:
	if _bosses == null or _boss_config == null:
		return false
	var type_id := _boss_config.type_index
	var i := _swarm.spawn_at(sites.centers[s], type_id, s, false)
	if i < 0:
		return false
	var health := _swarm.type_max_health(type_id) \
			* (1.0 + _boss_config.health_growth * (sites.levels[s] - 1))
	if _bosses.add(i, health) < 0:
		# No free boss slot: it stays an ordinary, if sturdy, camp member.
		_swarm.state.health[i] = health
	return true


func _despawn_site(s: int) -> void:
	_swarm.remove_camp(s)
	sites.make_dormant(s)


func _wake(s: int) -> void:
	sites.awake[s] = 1
	_swarm.state.camp_alarm[s] = 0
	_swarm.wake_camp(s)
