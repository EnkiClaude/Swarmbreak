class_name SwarmManager
extends Node3D
## Owns the swarm: packed-array state, flow field, spatial hash, steering,
## damage and rendering. No enemy is ever a Node; everything here works on
## indices into SwarmState.
##
## Each frame: simulate(), then any damage (damage_circle / first_hit), then
## resolve_deaths(), then draw(). Or call tick() when nothing deals damage.

@export var config: SwarmConfig

var state: SwarmState
## Wall time of the last frame's swarm work in microseconds, for the debug overlay.
var last_tick_usec: int = 0
var total_kills: int = 0
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
var _death_effects: PackedInt32Array = []
var _half_extent: float
var _time := 0.0
var _frame_usec := 0


## effects may be null (benchmarks, tests): deaths then show no effect.
func setup(arena_half_extent: float, effects: EffectSystem = null) -> void:
	_half_extent = arena_half_extent
	_effects = effects
	_types = SwarmTypeTable.new(config.enemy_types)
	if _types.largest_separation_radius() > config.hash_cell_size:
		push_warning("Swarm: a separation radius exceeds hash_cell_size; neighbours will be missed.")
	state = SwarmState.new(config.capacity)
	_grid = SpatialHash.new(arena_half_extent, config.hash_cell_size, config.capacity)
	_flow = FlowField.new(arena_half_extent, config.flow_cell_size)
	_steering = SwarmSteering.new(state, _grid, _flow, _types,
			config.direct_chase_distance, arena_half_extent, config.max_separation_neighbours)
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
func spawn_at(pos: Vector2, type_id: int = 0) -> int:
	var h := Vector2(_half_extent, _half_extent)
	return state.spawn(pos.clamp(-h, h), type_id, _types.max_health[type_id])


func tick(delta: float, player_pos: Vector2, player_radius: float) -> void:
	simulate(delta, player_pos, player_radius)
	resolve_deaths()
	draw()


## Moves the swarm. Enemy indices stay valid until resolve_deaths().
func simulate(delta: float, player_pos: Vector2, player_radius: float) -> void:
	var start := Time.get_ticks_usec()
	_time += delta
	_flow.update(player_pos)
	_grid.build(state.positions, state.count)
	_steering.step(player_pos, player_radius, delta)
	_frame_usec = Time.get_ticks_usec() - start


## Damages every enemy within radius of center. Returns how many died.
func damage_circle(center: Vector2, radius: float, damage: float, knockback: float) -> int:
	var kills := _combat.damage_circle(center, radius, damage, knockback,
			_time + config.hit_flash_duration)
	total_kills += kills
	best_break = maxi(best_break, kills)
	return kills


## Index of a live enemy touching the circle, or -1.
func first_hit(point: Vector2, radius: float) -> int:
	return _combat.first_hit(point, radius)


## Removes enemies killed this frame and spawns their death effects.
func resolve_deaths() -> void:
	var start := Time.get_ticks_usec()
	var dead := state.remove_dead()
	if _effects != null:
		var positions := state.dead_positions
		var types := state.dead_types
		var body_radius := _types.body_radius
		for k in dead:
			var p: Vector2 = positions[k]
			var t: int = types[k]
			_effects.spawn(_death_effects[t], Vector3(p.x, 0.0, p.y), body_radius[t])
	_frame_usec += Time.get_ticks_usec() - start


func draw() -> void:
	var start := Time.get_ticks_usec()
	_renderer.draw(state, _time)
	last_tick_usec = _frame_usec + Time.get_ticks_usec() - start


func enemy_count() -> int:
	return state.count
