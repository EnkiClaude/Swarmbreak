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
const EXIT_INSET := 4.0
const ARRIVAL_INSET := 17.0
## Coming out of a dungeon, the player stands this far south of its gate.
const GATE_STEP_OUT := 5.0
const TOWN_GATE_SPACING := 9.0
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
	return Vector2(0.0, layouts[d].south_end() - ARRIVAL_INSET)


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


## Several camps per side room, spread over it (in the room at spawner_depth,
## spawner_count of them are spawners); the boss room holds the boss at its
## center, more camps around it and spawners near its walls. Each room is a
## level harder than the one before (depth_level_step).
func _dungeon_camps(d: int, rng: RandomNumberGenerator) -> CampSites:
	var def := config.dungeons[d]
	var layout := layouts[d]
	var sites := CampSites.new()
	for room in layout.rooms.size():
		var depth := layout.depths[room]
		var level := def.level + depth * def.depth_level_step
		var rect := layout.rooms[room]
		if room == layout.boss_room:
			if def.has_boss:
				_dungeon_site(sites, def, rect.get_center(), def.boss_camp_size, level, depth,
						true, false)
			for k in def.boss_room_camps:
				# A ring around the boss, halfway to the walls.
				var a := TAU * (k + 0.5) / maxf(def.boss_room_camps, 1)
				var at := rect.get_center() + Vector2(cos(a) * rect.size.x * 0.3,
						sin(a) * rect.size.y * 0.3)
				_dungeon_site(sites, def, at, rng.randi_range(def.camp_size_min,
						def.camp_size_max), level, depth, false, false)
			for k in def.boss_room_spawners:
				var side := -1.0 if k % 2 == 0 else 1.0
				var at := rect.get_center() + Vector2(side * rect.size.x * 0.38,
						(0.25 if k < 2 else -0.25) * rect.size.y)
				_dungeon_site(sites, def, at, def.spawner_population, level, depth, false, true)
			continue
		var spawners := def.spawner_count if depth == def.spawner_depth else 0
		var grid := _camp_grid(rect, def.camps_per_room)
		for k in grid.size():
			if k < spawners:
				_dungeon_site(sites, def, grid[k], def.spawner_population, level, depth, false,
						true)
			else:
				_dungeon_site(sites, def, grid[k], rng.randi_range(def.camp_size_min,
						def.camp_size_max), level, depth, false, false)
	return sites


func _dungeon_site(sites: CampSites, def: DungeonDef, at: Vector2, size: int, level: int,
		depth: int, boss: bool, spawner: bool) -> void:
	var s := sites.add(at, size, level, def.heavy_chance, boss, spawner,
			def.spawner_interval if spawner else 0.0, def.camp_respawn_time)
	sites.set_types(s, def.enemy_type, def.heavy_type)
	sites.depth[s] = depth


## count camp centers spread over a room: a grid two wide along its short side.
static func _camp_grid(rect: Rect2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if count <= 0:
		return points
	var across := 2 if count > 1 else 1
	var rows := ceili(float(count) / across)
	var wide := rect.size.x >= rect.size.y
	for k in count:
		var row := floori(float(k) / across)
		var col := k % across
		var along := (row + 0.5) / rows
		var side := (col + 0.5) / across
		var f := Vector2(along, side) if wide else Vector2(side, along)
		points.append(rect.position + rect.size * f)
	return points


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
