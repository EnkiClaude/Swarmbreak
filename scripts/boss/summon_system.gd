class_name SummonSystem
extends RefCounted
## The summonable boss (SummonConfig): spends the player's shards to call
## the boss and an awake escort a little ahead of the player (not in town),
## tracks which boss slot is the summoned one so its kill pays out the big
## rewards, and allows one at a time. Spawning only appends to the swarm, so
## it's safe outside the damage window (e.g. from the menu).

signal summoned(at: Vector2)

var config: SummonConfig
var _swarm: SwarmManager
var _bosses: BossSystem
var _boss_config: BossConfig
var _inventory: Inventory
var _world: WorldDirector
var _player: Player
var _progress: PlayerProgress
## Boss slot of the summoned boss, or -1.
var _slot := -1


func _init(p_config: SummonConfig, swarm: SwarmManager, bosses: BossSystem,
		boss_config: BossConfig, inventory: Inventory, world: WorldDirector, player: Player,
		progress: PlayerProgress) -> void:
	config = p_config
	_swarm = swarm
	_bosses = bosses
	_boss_config = boss_config
	_inventory = inventory
	_world = world
	_player = player
	_progress = progress


## Why the boss can't be summoned right now, or "" if it can.
func blocker() -> String:
	if _inventory.summon_shards < config.shards_needed:
		return "Needs %d %ss (you have %d)" % [config.shards_needed, config.shard_name,
				_inventory.summon_shards]
	if _world.is_town():
		return "Not in town: summon it out in the wilds or in a dungeon"
	if is_active():
		return "The %s is already here" % config.boss_name
	return ""


func is_active() -> bool:
	return _slot >= 0 and _bosses.index_of(_slot) >= 0


func is_summoned(slot: int) -> bool:
	return slot == _slot


## The level the boss fights at: the place's level or the player's, higher.
func level() -> int:
	return maxi(_world.level(), _progress.level)


## Spends the shards and calls the boss. False (and nothing spent) if it can't.
func summon() -> bool:
	if blocker() != "":
		return false
	var aim := _player.aim_direction
	var at := _player.ground_position() + Vector2(aim.x, aim.z) * config.spawn_distance
	var i := _swarm.spawn_at(at, config.boss_type, -1, true)
	if i < 0:
		return false
	var lvl := level()
	var health := _swarm.type_max_health(config.boss_type) \
			* (1.0 + _boss_config.health_growth * (lvl - 1)) * config.health_multiplier
	var slot := _bosses.add(i, health)
	if slot < 0:
		_swarm.state.health[i] = 0.0
		return false
	_slot = slot
	_inventory.add_summon_shards(-config.shards_needed)
	var escort_health := _world.camps.health_multiplier(lvl)
	for k in config.escort_count:
		var offset := Vector2.from_angle(k * 2.39996) * config.escort_spread * sqrt((k + 0.5)
				/ maxf(config.escort_count, 1))
		var e := _swarm.spawn_at(at + offset, config.escort_type, -1, true)
		if e >= 0:
			_swarm.state.health[e] *= escort_health
	summoned.emit(at)
	return true


## The summoned boss died: forget it.
func on_killed(slot: int) -> void:
	if slot == _slot:
		_slot = -1


## Travel empties the swarm: whatever was summoned is gone.
func reset() -> void:
	_slot = -1
