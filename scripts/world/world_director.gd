class_name WorldDirector
extends RefCounted
## Runs the world: which space the player is in (the open world or a
## dungeon), which region, and travel between them. Builds every space's
## scenery once and shows only the active one. In the open world, walking
## into another region announces it and eases the atmosphere over; walking
## into a gate fades out, switches space (the swarm empties, the new space's
## camps stream in, every system gets the new bounds) and fades back in.

## The player entered a region of the open world, or a dungeon.
signal location_entered(title: String, level: int, is_town: bool)
signal space_entered(space: int)

var map: WorldMap
var camps: CampDirector
var atmosphere: WorldAtmosphere
## WorldMap.OVERWORLD or a dungeon index.
var space := WorldMap.OVERWORLD
## The open-world region the player is in (-1 inside a dungeon).
var region := -1
## 0..1: how dark the screen is during a gate transition.
var fade := 0.0

var _config: WorldConfig
var _swarm: SwarmManager
var _overworld: Node3D
var _dungeons: Array[Node3D] = []
var _player: Player
var _camera: CameraRig
var _projectiles: ProjectileSystem
var _loot: LootSystem
## Pending travel: the space and point to switch to once faded out.
var _travel_space := WorldMap.OVERWORLD
var _travel_at := Vector2.ZERO
var _travelling := false
var _switched := false
## Where leaving the current dungeon puts the player: outside the gate they
## came in through (its own entrance or the one in town).
var _return_point := Vector2.ZERO


func _init(config: WorldConfig, swarm: SwarmManager, bosses: BossSystem,
		boss_config: BossConfig, scenery_parent: Node3D, environment: Environment,
		sun: DirectionalLight3D) -> void:
	_config = config
	_swarm = swarm
	map = WorldMap.new(config)
	camps = CampDirector.new(config, swarm, bosses, boss_config)
	atmosphere = WorldAtmosphere.new(environment, sun)
	atmosphere.blend_time = config.atmosphere_blend_time
	_overworld = OverworldScenery.build(scenery_parent, map)
	for d in config.dungeons.size():
		var def := config.dungeons[d]
		var hall := DungeonHall.new()
		hall.name = "Dungeon%d" % d
		scenery_parent.add_child(hall)
		hall.build(def.theme, map.layouts[d])
		GateProp.build(hall, map.exit_position(d), "Exit", def.gate_color)
		hall.visible = false
		_dungeons.append(hall)


## The systems that follow the player between spaces.
func setup_actors(player: Player, camera: CameraRig, projectiles: ProjectileSystem,
		loot: LootSystem) -> void:
	_player = player
	_camera = camera
	_projectiles = projectiles
	_loot = loot


## Moves the player into a space at a ground point right away.
func enter(new_space: int, at: Vector2) -> void:
	space = new_space
	region = -1
	_swarm.clear()
	camps.speed_by_level = space != WorldMap.OVERWORLD
	camps.use_sites(map.sites(space))
	var h := map.half_extent(space)
	_swarm.set_bounds(h)
	_player.set_bounds(h)
	_camera.set_bounds(h)
	_projectiles.set_bounds(h)
	if space == WorldMap.OVERWORLD:
		_swarm.clear_layout()
	else:
		var layout: DungeonLayout = map.layouts[space]
		_swarm.set_layout(layout, _config.dungeon_chase_distance,
				layout.homes_for(map.sites(space).centers))
	_loot.clear()
	_overworld.visible = space == WorldMap.OVERWORLD
	for d in _dungeons.size():
		_dungeons[d].visible = d == space
	_player.reset_to(Vector3(at.x, 0.0, at.y))
	_camera.reset_view()
	_camera.follow(_player)
	if space == WorldMap.OVERWORLD:
		_enter_region(map.region_at(at), true)
	else:
		var def := _config.dungeons[space]
		atmosphere.set_target(def.theme, true)
		location_entered.emit(def.display_name, def.level, false)
	space_entered.emit(space)


## Back to town, e.g. after dying.
func return_to_town() -> void:
	_travelling = false
	fade = 0.0
	enter(WorldMap.OVERWORLD, map.town_spawn())


func tick(delta: float, player_pos: Vector2) -> void:
	atmosphere.tick(delta)
	if _travelling:
		_tick_travel(delta)
		return
	if space == WorldMap.OVERWORLD:
		var now_in := map.region_at(player_pos)
		if now_in != region:
			_enter_region(now_in, false)
		for d in _config.dungeons.size():
			for gate: Vector2 in [map.gate_position(d), map.town_gate_position(d)]:
				if player_pos.distance_to(gate) <= _config.gate_radius:
					_return_point = gate + Vector2(0.0, WorldMap.GATE_STEP_OUT)
					_start_travel(d, map.arrival_point(d))
					return
	elif player_pos.distance_to(map.exit_position(space)) <= _config.gate_radius:
		var back := _return_point if _return_point != Vector2.ZERO \
				else map.gate_exit_point(space)
		_start_travel(WorldMap.OVERWORLD, back)


func is_travelling() -> bool:
	return _travelling


## Name of the region or dungeon the player is in.
func location_name() -> String:
	if space != WorldMap.OVERWORLD:
		return _config.dungeons[space].display_name
	return _config.regions[maxi(region, 0)].display_name


func is_town() -> bool:
	return space == WorldMap.OVERWORLD and region >= 0 and _config.regions[region].is_town


## Difficulty where the player is: the region's or the dungeon's level.
func level() -> int:
	if space != WorldMap.OVERWORLD:
		return _config.dungeons[space].level
	return _config.regions[maxi(region, 0)].level


func dungeon() -> DungeonDef:
	return _config.dungeons[space] if space != WorldMap.OVERWORLD else null


## Monster contact damage multiplier where the player is.
func damage_multiplier() -> float:
	var mult := (1.0 + _config.damage_growth * (level() - 1)) \
			* camps.gap_multiplier(level(), _config.gap_damage_per_level) * camps.toughness()
	var def := dungeon()
	return mult * def.damage_multiplier if def != null else mult


## The level gear drops at here: lower in the open world.
func item_level(level: int) -> int:
	if dungeon() != null:
		return level
	return maxi(1, roundi(level * _config.overworld_item_level_scale))


## The best rarity that drops here (-1: no cap; dungeons have none).
func max_rarity() -> int:
	return -1 if dungeon() != null else _config.overworld_max_rarity


## XP multiplier for kills where the player is.
func xp_multiplier() -> float:
	return 1.0 + _config.xp_growth * (level() - 1)


## Gates of the current space, for the minimap.
func gate_positions() -> PackedVector2Array:
	var gates := PackedVector2Array()
	if space == WorldMap.OVERWORLD:
		for d in _config.dungeons.size():
			gates.append(map.gate_position(d))
			gates.append(map.town_gate_position(d))
	else:
		gates.append(map.exit_position(space))
	return gates


func _enter_region(new_region: int, snap: bool) -> void:
	region = new_region
	var def := _config.regions[region]
	atmosphere.set_target(def.theme, snap)
	location_entered.emit(def.display_name, def.level, def.is_town)


func _start_travel(to_space: int, at: Vector2) -> void:
	_travelling = true
	_switched = false
	_travel_space = to_space
	_travel_at = at


func _tick_travel(delta: float) -> void:
	var step := delta / maxf(_config.fade_time, 0.001)
	if not _switched:
		fade = minf(fade + step, 1.0)
		if fade >= 1.0:
			_switched = true
			enter(_travel_space, _travel_at)
	else:
		fade = maxf(fade - step, 0.0)
		if fade <= 0.0:
			_travelling = false
