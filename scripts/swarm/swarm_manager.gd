class_name SwarmManager
extends Node3D
## Owns the swarm: packed-array state, flow field, spatial hash, steering and
## rendering. No enemy is ever a Node; everything here works on indices into
## SwarmState.

@export var config: SwarmConfig

var state: SwarmState
## Wall time of the last tick() in microseconds, for the debug overlay.
var last_tick_usec: int = 0

var _types: SwarmTypeTable
var _grid: SpatialHash
var _flow: FlowField
var _steering: SwarmSteering
var _spawner := SwarmSpawner.new()
var _renderer: SwarmRenderer
var _half_extent: float


func setup(arena_half_extent: float) -> void:
	_half_extent = arena_half_extent
	_types = SwarmTypeTable.new(config.enemy_types)
	if _types.largest_separation_radius() > config.hash_cell_size:
		push_warning("Swarm: a separation radius exceeds hash_cell_size; neighbours will be missed.")
	state = SwarmState.new(config.capacity)
	_grid = SpatialHash.new(arena_half_extent, config.hash_cell_size, config.capacity)
	_flow = FlowField.new(arena_half_extent, config.flow_cell_size)
	_steering = SwarmSteering.new(state, _grid, _flow, _types,
			config.direct_chase_distance, arena_half_extent)
	_renderer = SwarmRenderer.new()
	_renderer.name = "Renderer"
	add_child(_renderer)
	_renderer.setup(config.enemy_types, config.capacity)


## Spawns enemies of the given type in a ring around center. Returns the number spawned.
func spawn_around(center: Vector2, amount: int, type_id: int = 0) -> int:
	return _spawner.spawn_ring(state, amount, center, config.spawn_min_distance,
			config.spawn_max_distance, type_id, _half_extent)


func tick(delta: float, player_pos: Vector2, player_radius: float) -> void:
	var start := Time.get_ticks_usec()
	_flow.update(player_pos)
	_grid.build(state.positions, state.count)
	_steering.step(player_pos, player_radius, delta)
	_renderer.draw(state)
	last_tick_usec = Time.get_ticks_usec() - start


func enemy_count() -> int:
	return state.count
