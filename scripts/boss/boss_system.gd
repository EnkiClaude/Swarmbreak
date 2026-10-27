class_name BossSystem
extends RefCounted
## Runs camp bosses. A boss is an ordinary swarm enemy in a boss slot
## (SwarmState.boss_index tracks where it currently lives). Once awake, a
## boss that gets close starts a ground slam: it stops, a red ring grows
## for slam_windup seconds, then everything inside takes the hit. Dodging
## out of the ring, or through it with i-frames, avoids it.

signal slam_started(center: Vector2)
## inside: the player stood in the ring. damage: what it actually took
## (0 while dodging or otherwise invulnerable).
signal slammed(center: Vector2, inside: bool, damage: float)
signal boss_killed(slot: int, at: Vector2)

var _config: BossConfig
var _swarm: SwarmManager
var _effects: EffectSystem
var _telegraph := -1
var _count := 0
var _alive: PackedByteArray = []
var _last_pos: PackedVector2Array = []
var _max_health: PackedFloat32Array = []
var _cooldown: PackedFloat32Array = []
var _windup: PackedFloat32Array = []
var _slam_center: PackedVector2Array = []


func _init(config: BossConfig, swarm: SwarmManager, effects: EffectSystem) -> void:
	_config = config
	_swarm = swarm
	_effects = effects
	_telegraph = effects.register(config.telegraph_effect) if effects != null else -1
	var n := config.max_per_zone
	_alive.resize(n)
	_last_pos.resize(n)
	_max_health.resize(n)
	_cooldown.resize(n)
	_windup.resize(n)
	_slam_center.resize(n)
	reset()


func reset() -> void:
	_count = 0
	_alive.fill(0)
	_windup.fill(0.0)
	_cooldown.fill(0.0)


## Turns enemy `index` into the next boss. Returns its slot, or -1 if full.
func add(index: int, health: float) -> int:
	if _count >= _config.max_per_zone:
		return -1
	var slot := _count
	_count += 1
	_swarm.state.make_boss(index, slot)
	_swarm.state.health[index] = health
	_alive[slot] = 1
	_max_health[slot] = health
	_last_pos[slot] = _swarm.state.positions[index]
	_cooldown[slot] = _config.slam_cooldown * 0.5
	return slot


func count() -> int:
	return _count


func alive_count() -> int:
	var n := 0
	for slot in _count:
		n += _alive[slot]
	return n


## Enemy index of a boss slot (or -1 if dead).
func index_of(slot: int) -> int:
	return _swarm.state.boss_index[slot] if slot < _count else -1


func is_winding_up(slot: int) -> bool:
	return _windup[slot] > 0.0


## Call after resolve_deaths(). Damages the player through vitals.
func tick(delta: float, player_pos: Vector2, vitals: PlayerVitals) -> void:
	var state := _swarm.state
	var now := _swarm.now()
	for slot in _count:
		if _alive[slot] == 0:
			continue
		var i: int = state.boss_index[slot]
		if i < 0:
			_alive[slot] = 0
			boss_killed.emit(slot, _last_pos[slot])
			continue
		var pos: Vector2 = state.positions[i]
		_last_pos[slot] = pos
		if state.awake[i] == 0:
			continue
		if _windup[slot] > 0.0:
			_swarm.stun(i, delta * 2.0)
			_windup[slot] -= delta
			if _windup[slot] <= 0.0:
				_slam(slot, player_pos, vitals, now)
			continue
		_cooldown[slot] -= delta
		if _cooldown[slot] <= 0.0 and pos.distance_to(player_pos) <= _config.slam_trigger_range:
			_windup[slot] = _config.slam_windup
			_cooldown[slot] = _config.slam_cooldown
			_slam_center[slot] = pos
			_swarm.stun(i, _config.slam_windup)
			if _effects != null:
				_effects.spawn(_telegraph, Vector3(pos.x, 0.0, pos.y), _config.slam_radius)
			slam_started.emit(pos)


## The nearest awake boss within hud_range: [slot, health fraction], or [-1, 0].
func hud_target(player_pos: Vector2) -> Array:
	var best := -1
	var best_d := _config.hud_range
	var state := _swarm.state
	for slot in _count:
		var i := index_of(slot)
		if i < 0 or state.awake[i] == 0:
			continue
		var d := state.positions[i].distance_to(player_pos)
		if d <= best_d:
			best_d = d
			best = slot
	if best < 0:
		return [-1, 0.0]
	return [best, clampf(state.health[index_of(best)] / _max_health[best], 0.0, 1.0)]


func _slam(slot: int, player_pos: Vector2, vitals: PlayerVitals, now: float) -> void:
	var center := _slam_center[slot]
	var inside := player_pos.distance_to(center) <= _config.slam_radius
	var taken := vitals.take_damage(_config.slam_damage, now) if inside else 0.0
	slammed.emit(center, inside, taken)
