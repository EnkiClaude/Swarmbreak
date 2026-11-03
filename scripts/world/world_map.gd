class_name WorldMap
extends RefCounted
## The world's fixed layout, generated once from WorldConfig with a seed: the
## region grid of the open world (space -1), where each dungeon's gate stands,
## and the camp sites of every space. Dungeons are spaces 0, 1, ...; each is
## its own hall centered on the origin. Pure data and geometry: no nodes.

const OVERWORLD := -1
## In a dungeon the exit gate stands this far up the hallway from its south
## end (+Z), and the player arrives further up, facing north: far enough
## that the camera behind the player is clear of the gate.
const EXIT_INSET := 3.0
## Coming out of a dungeon, the player stands this far south of its gate.
const GATE_STEP_OUT := 5.0
const TOWN_GATE_SPACING := 7.0
const TOWN_GATE_DISTANCE := 16.0

var config: WorldConfig
var overworld_sites: CampSites
var dungeon_sites: Array[CampSites] = []
## Each dungeon's floor plan.
var layouts: Array[DungeonLayout] = []


func _init(p_config: WorldConfig) -> void:
	config = p_config
	_generate()


func half_extent(space: int) -> float:
	if space == OVERWORLD:
		return config.half_extent()
	return layouts[space].half_extent()


func sites(space: int) -> CampSites:
	return overworld_sites if space == OVERWORLD else dungeon_sites[space]


## Index of the region containing ground position p (clamped to the grid).
func region_at(p: Vector2) -> int:
	var n := config.grid_size
	var h := config.half_extent()
	var col := clampi(floori((p.x + h) / config.region_size), 0, n - 1)
	var row := clampi(floori((p.y + h) / config.region_size), 0, n - 1)
	return row * n + col


func region_center(region: int) -> Vector2:
	var n := config.grid_size
	var h := config.half_extent()
	var half_cell := config.region_size * 0.5
	@warning_ignore("integer_division")
	var row := region / n
	return Vector2(-h + (region % n) * config.region_size + half_cell,
			-h + row * config.region_size + half_cell)


## Where the player stands in town: at its center.
func town_spawn() -> Vector2:
	return region_center(config.town_region())


## Open-world position of dungeon d's entrance gate.
func gate_position(d: int) -> Vector2:
	var dungeon := config.dungeons[d]
	return region_center(dungeon.region) + dungeon.gate_offset


## A second gate to dungeon d at the north edge of the town square, for
## quick travel while testing. Gates spread out side by side.
func town_gate_position(d: int) -> Vector2:
	var spread := (d - (config.dungeons.size() - 1) * 0.5) * TOWN_GATE_SPACING
	return town_spawn() + Vector2(spread, -TOWN_GATE_DISTANCE)


## Where the player lands in the open world when leaving dungeon d.
func gate_exit_point(d: int) -> Vector2:
	return gate_position(d) + Vector2(0.0, GATE_STEP_OUT)


## Position of dungeon d's exit gate inside its hall.
func exit_position(d: int) -> Vector2:
	return Vector2(0.0, layouts[d].south_end() - EXIT_INSET)


## Where the player lands inside dungeon d.
func arrival_point(d: int) -> Vector2:
	return layouts[d].arrival()


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.world_seed
	overworld_sites = CampSites.new()
	var keep_clear := PackedVector2Array()
	for d in config.dungeons.size():
		keep_clear.append(gate_position(d))
	for region in config.regions.size():
		_place_region_camps(region, rng, keep_clear)
	for d in config.dungeons.size():
		layouts.append(DungeonLayout.new(config.dungeons[d]))
		dungeon_sites.append(_dungeon_camps(d, rng))


func _place_region_camps(region: int, rng: RandomNumberGenerator,
		keep_clear: PackedVector2Array) -> void:
	var def := config.regions[region]
	if def.is_town or def.camp_count <= 0:
		return
	var center := region_center(region)
	var inner := config.region_size * 0.5 - config.edge_margin
	var world_limit := config.half_extent() - config.edge_margin
	var town := town_spawn()
	var town_reach := config.region_size * 0.5 + config.edge_margin
	var placed := PackedVector2Array()
	var sizes := PackedInt32Array()
	for _attempt in config.placement_attempts:
		if placed.size() >= def.camp_count:
			break
		var at := center + Vector2(rng.randf_range(-inner, inner), rng.randf_range(-inner, inner))
		if absf(at.x) > world_limit or absf(at.y) > world_limit:
			continue
		# Keep the town's edge quiet too: no camp right outside its border.
		if absf(at.x - town.x) < town_reach and absf(at.y - town.y) < town_reach:
			continue
		if too_close(at, keep_clear, config.keep_clear_radius) \
				or too_close(at, overworld_sites.centers, config.camp_spacing) \
				or too_close(at, placed, config.camp_spacing):
			continue
		placed.append(at)
		sizes.append(rng.randi_range(def.camp_size_min, def.camp_size_max))
	var bosses := _biggest(sizes, def.boss_camps)
	for k in placed.size():
		var s := overworld_sites.add(placed[k], sizes[k], def.level, def.heavy_chance,
				bosses.has(k), false, 0.0, config.camp_respawn_time)
		overworld_sites.set_types(s, def.enemy_type, def.heavy_type)


## The arena holds arena_camps camps spread over it (the first
## arena_spawners of them spawners); the boss room holds the boss in its
## middle and boss_room_camps camps in a ring around it (plus spawners), a
## level step harder. The lobby holds nothing: it's safe.
func _dungeon_camps(d: int, rng: RandomNumberGenerator) -> CampSites:
	var def := config.dungeons[d]
	var layout := layouts[d]
	var sites := CampSites.new()
	var arena := layout.rooms[DungeonLayout.ARENA]
	var spots := _spread(arena, def.arena_camps)
	for k in spots.size():
		var spawner := k < def.arena_spawners
		_dungeon_site(sites, def, spots[k], def.spawner_population if spawner
				else rng.randi_range(def.camp_size_min, def.camp_size_max), def.level, 0, false,
				spawner)
	var boss := layout.rooms[layout.boss_room]
	var level := def.level + def.depth_level_step
	if def.has_boss:
		_dungeon_site(sites, def, boss.get_center(), def.boss_camp_size, level, 1, true, false)
	var count := def.boss_room_camps + def.boss_room_spawners
	for k in count:
		var a := TAU * (k + 0.5) / maxf(count, 1)
		var at := boss.get_center() + Vector2(cos(a) * boss.size.x * 0.36,
				sin(a) * boss.size.y * 0.36)
		var spawner := k < def.boss_room_spawners
		_dungeon_site(sites, def, at, def.spawner_population if spawner
				else rng.randi_range(def.camp_size_min, def.camp_size_max), level, 1, false, spawner)
	return sites


## count points spread over a room: one in the middle, the rest in a ring.
static func _spread(rect: Rect2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if count <= 0:
		return points
	points.append(rect.get_center())
	var ring := count - 1
	for k in ring:
		var a := TAU * (k + 0.5) / maxf(ring, 1)
		points.append(rect.get_center() + Vector2(cos(a) * rect.size.x * 0.33,
				sin(a) * rect.size.y * 0.33))
	return points


func _dungeon_site(sites: CampSites, def: DungeonDef, at: Vector2, size: int, level: int,
		depth: int, boss: bool, spawner: bool) -> void:
	var s := sites.add(at, size, level, def.heavy_chance, boss, spawner,
			def.spawner_interval if spawner else 0.0, def.camp_respawn_time,
			def.instant_respawn and not spawner and not boss)
	sites.set_types(s, def.enemy_type, def.heavy_type)
	sites.depth[s] = depth



static func too_close(at: Vector2, others: PackedVector2Array, distance: float) -> bool:
	var d_sq := distance * distance
	for other in others:
		if at.distance_squared_to(other) < d_sq:
			return true
	return false


## Indices of the `count` largest sizes.
static func _biggest(sizes: PackedInt32Array, count: int) -> PackedInt32Array:
	var picked := PackedInt32Array()
	while picked.size() < mini(count, sizes.size()):
		var best := -1
		for k in sizes.size():
			if not picked.has(k) and (best < 0 or sizes[k] > sizes[best]):
				best = k
		picked.append(best)
	return picked
