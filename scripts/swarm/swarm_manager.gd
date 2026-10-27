class_name SwarmManager
extends Node3D
## Owns the swarm: packed-array state, flow field, spatial hash, steering,
## damage and rendering. No enemy is ever a Node; everything here works on
## indices into SwarmState.
##
## Each frame: simulate(), then any damage (damage_circle / first_hit), then
## resolve_deaths(), then draw(). Or call tick() when nothing deals damage.

## Emitted by every damage event that kills at least one enemy.
signal enemies_killed(count: int, center: Vector2)

@export var config: SwarmConfig

var state: SwarmState
## Wall time of the last frame's swarm work in microseconds, for the debug overlay.
var last_tick_usec: int = 0
var total_kills: int = 0
## XP earned from the enemies removed by the last resolve_deaths().
var last_xp := 0.0
## Extra damage marked enemies take (set from the Warlord job's perks).
var mark_damage_bonus := 0.0
## Most kills from a single damage event: the biggest "break" so far.
var best_break: int = 0

var _types: SwarmTypeTable
var _grid: SpatialHash
var _flow: FlowField
var _steering: SwarmSteering
var _combat: SwarmCombat
var _spawner := SwarmSpawner.new()
var _renderer: SwarmRenderer
var _effects: EffectSystem
var _corpses: CorpseSystem
var _death_effects: PackedInt32Array = []
var _half_extent: float
var _time := 0.0
var _frame_usec := 0


## effects and corpses may be null (benchmarks, tests): deaths then show nothing.
## max_camps sizes the camp alarm flags, max_bosses the boss slots.
func setup(arena_half_extent: float, effects: EffectSystem = null,
		corpses: CorpseSystem = null, max_camps: int = 1, max_bosses: int = 1) -> void:
	_half_extent = arena_half_extent
	_effects = effects
	_corpses = corpses
	_types = SwarmTypeTable.new(config.enemy_types)
	state = SwarmState.new(config.capacity, max_camps, max_bosses)
	_grid = SpatialHash.new(config.hash_cell_size, config.hash_buckets, config.capacity)
	_flow = FlowField.new(arena_half_extent, config.flow_cell_size)
	_steering = SwarmSteering.new(state, _grid, _flow, _types,
			config.direct_chase_distance, arena_half_extent, config.max_separation_neighbours,
			config.max_attackers)
	_combat = SwarmCombat.new(state, _grid, _types)
	_renderer = SwarmRenderer.new()
	_renderer.name = "Renderer"
	add_child(_renderer)
	_renderer.setup(config.enemy_types, config.capacity, config.hit_flash_color)
	for t in config.enemy_types:
		_death_effects.append(effects.register(t.death_effect) if effects != null else -1)


## Spawns enemies of the given type in a ring around center. Returns the number spawned.
func spawn_around(center: Vector2, amount: int, type_id: int = 0) -> int:
	return _spawner.spawn_ring(state, amount, center, config.spawn_min_distance,
			config.spawn_max_distance, type_id, _types.max_health[type_id], _half_extent)


## Spawns one enemy at an exact spot. Returns its index, or -1 if the pool is full.
## Camp members spawn asleep unless is_awake is set.
func spawn_at(pos: Vector2, type_id: int = 0, camp_id: int = -1, is_awake: bool = true) -> int:
	var h := Vector2(_half_extent, _half_extent)
	return state.spawn(pos.clamp(-h, h), type_id, _types.max_health[type_id], camp_id, is_awake)


## Wakes every member of a camp. Returns how many were asleep.
func wake_camp(camp_id: int) -> int:
	var camp_ids := state.camp_ids
	var awake := state.awake
	var woken := 0
	for i in state.count:
		if camp_ids[i] == camp_id and awake[i] == 0:
			awake[i] = 1
			woken += 1
	return woken


## Speeds up every awake enemy within radius of center for duration seconds.
func boost_within(center: Vector2, radius: float, duration: float) -> int:
	var positions := state.positions
	var awake := state.awake
	var boost := state.boost_until
	var until := _time + duration
	var r_sq := radius * radius
	var boosted := 0
	for i in state.count:
		if awake[i] != 0 and (positions[i] - center).length_squared() <= r_sq:
			boost[i] = until
			boosted += 1
	return boosted


## Marks every awake enemy within radius so it takes mark_damage_bonus extra damage.
func mark_within(center: Vector2, radius: float, duration: float) -> int:
	var positions := state.positions
	var awake := state.awake
	var marks := state.mark_until
	var until := _time + duration
	var r_sq := radius * radius
	var marked := 0
	for i in state.count:
		if awake[i] != 0 and (positions[i] - center).length_squared() <= r_sq:
			marks[i] = until
			marked += 1
	return marked


## Holds an enemy still for duration seconds.
func stun(index: int, duration: float) -> void:
	state.stun_until[index] = maxf(state.stun_until[index], _time + duration)


func type_max_health(type_id: int) -> float:
	return _types.max_health[type_id]


## Removes every enemy, e.g. when a zone restarts.
func clear() -> void:
	state.clear()
	_renderer.draw(state, _time)


func now() -> float:
	return _time


## Damage per second the player is taking from touching enemies, as of the last simulate().
func contact_dps() -> float:
	return _steering.contact_dps


func contact_count() -> int:
	return _steering.contact_count


func tick(delta: float, player_pos: Vector2, player_radius: float) -> void:
	simulate(delta, player_pos, player_radius)
	resolve_deaths()
	draw()


## Moves the swarm. Enemy indices stay valid until resolve_deaths().
## boost_multiplier is the speed factor for lure-boosted enemies.
func simulate(delta: float, player_pos: Vector2, player_radius: float,
		boost_multiplier: float = 1.0) -> void:
	var start := Time.get_ticks_usec()
	_time += delta
	_flow.update(player_pos)
	_grid.build(state.positions, state.count)
	_steering.step(player_pos, player_radius, delta, _time, boost_multiplier)
	_frame_usec = Time.get_ticks_usec() - start


## Damages every enemy within radius of center. Returns how many died.
func damage_circle(center: Vector2, radius: float, damage: float, knockback: float) -> int:
	var kills := _combat.damage_circle(center, radius, damage, knockback,
			_time + config.hit_flash_duration, _time, mark_damage_bonus)
	total_kills += kills
	best_break = maxi(best_break, kills)
	if kills > 0:
		enemies_killed.emit(kills, center)
	return kills


## Index of a live enemy touching the circle, or -1.
func first_hit(point: Vector2, radius: float) -> int:
	return _combat.first_hit(point, radius)


## Removes enemies killed this frame and spawns their death effects and
## corpses. Returns how many died; their details are in state.dead_*.
func resolve_deaths() -> int:
	var start := Time.get_ticks_usec()
	var dead := state.remove_dead()
	var positions := state.dead_positions
	var types := state.dead_types
	var xp_table := _types.xp
	last_xp = 0.0
	for k in dead:
		last_xp += xp_table[types[k]]
	if _effects != null:
		var body_radius := _types.body_radius
		for k in dead:
			var p: Vector2 = positions[k]
			var t: int = types[k]
			_effects.spawn(_death_effects[t], Vector3(p.x, 0.0, p.y), body_radius[t])
	if _corpses != null:
		var velocities := state.dead_velocities
		for k in dead:
			_corpses.spawn(types[k], positions[k], velocities[k])
	_frame_usec += Time.get_ticks_usec() - start
	return dead


func draw() -> void:
	var start := Time.get_ticks_usec()
	_renderer.draw(state, _time)
	last_tick_usec = _frame_usec + Time.get_ticks_usec() - start


func enemy_count() -> int:
	return state.count
