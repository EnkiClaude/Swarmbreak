extends TestSuite

const WORLD := "res://data/world/world.tres"


func _config() -> WorldConfig:
	return load(WORLD) as WorldConfig


## A real swarm (headless), so camps can stream in and out of it.
func _swarm() -> SwarmManager:
	var swarm := SwarmManager.new()
	swarm.config = load("res://data/swarm.tres") as SwarmConfig
	swarm.setup(64.0, null, null, 128, 8)
	return swarm


## Runs a director at a spot for a few streaming passes.
func _run(director: CampDirector, swarm: SwarmManager, at: Vector2, seconds: float) -> void:
	var steps := ceili(seconds / 0.1)
	for n in steps:
		swarm.simulate(0.1, at, 0.5)
		director.record_deaths(swarm.resolve_deaths())
		director.tick(at)


func test_world_layout_is_consistent() -> void:
	var config := _config()
	check_eq(config.regions.size(), config.grid_size * config.grid_size, "a region per cell")
	var towns := 0
	for region in config.regions:
		check(region.theme != null, "%s has a theme" % region.display_name)
		towns += 1 if region.is_town else 0
	check_eq(towns, 1, "one town")
	check(config.dungeons.size() >= 2, "dungeons (%d)" % config.dungeons.size())
	for dungeon in config.dungeons:
		check(dungeon.region >= 0 and dungeon.region < config.regions.size(), "gate region exists")
		check(dungeon.level > config.regions[dungeon.region].level,
				"%s is harder than its region" % dungeon.display_name)


func test_regions_map_both_ways() -> void:
	var map := WorldMap.new(_config())
	for r in map.config.regions.size():
		check_eq(map.region_at(map.region_center(r)), r, "region %d round trip" % r)
	check_eq(map.region_at(map.town_spawn()), map.config.town_region(), "town spawn is in town")
	var h := map.config.half_extent()
	check_eq(map.region_at(Vector2(-h - 50.0, -h - 50.0)), 0, "outside clamps to a corner")


func test_open_world_camps_are_placed_sensibly() -> void:
	var map := WorldMap.new(_config())
	var config := map.config
	var sites := map.overworld_sites
	check(sites.size() >= 30, "%d camps in the open world" % sites.size())
	var limit := config.half_extent() - config.edge_margin + 0.01
	var bosses := 0
	for s in sites.size():
		var at := sites.centers[s]
		var region := map.region_at(at)
		check(not config.regions[region].is_town, "no camp in town (%s)" % at)
		check(absf(at.x) <= limit and absf(at.y) <= limit, "inside the world (%s)" % at)
		check_eq(sites.levels[s], config.regions[region].level, "camp level is its region's")
		for d in config.dungeons.size():
			check(at.distance_to(map.gate_position(d)) >= config.keep_clear_radius,
					"no camp on a gate")
		bosses += sites.has_boss[s]
		check_eq(sites.is_spawner[s], 0, "no spawners in the open world yet")
	check(bosses >= 4, "bosses in the open world (%d)" % bosses)


func test_dungeons_have_a_boss_spawners_and_room_to_arrive() -> void:
	var map := WorldMap.new(_config())
	var config := map.config
	for d in config.dungeons.size():
		var def := config.dungeons[d]
		var sites := map.dungeon_sites[d]
		var spawners := 0
		var bosses := 0
		for s in sites.size():
			var at := sites.centers[s]
			check(map.layouts[d].room_at(at) > 0, "%s: camp %d stands in a room" % [def.display_name, s])
			check(at.distance_to(map.arrival_point(d)) >= config.keep_clear_radius * 0.99,
					"%s: no camp where the player arrives" % def.display_name)
			check(sites.levels[s] >= def.level, "dungeon camps are at least the dungeon's level")
			spawners += sites.is_spawner[s]
			bosses += sites.has_boss[s]
		check_eq(spawners, def.spawner_count, "%s spawners" % def.display_name)
		check_eq(bosses, 1, "%s has a boss" % def.display_name)
		# Arriving must not land on the way-out gate, or leaving bounce back in.
		check(map.arrival_point(d).distance_to(map.exit_position(d)) > config.gate_radius,
				"arrival is clear of the exit")
		check(map.gate_exit_point(d).distance_to(map.gate_position(d)) > config.gate_radius,
				"leaving is clear of the entrance")
		for s in sites.size():
			if sites.is_spawner[s] != 0:
				check(sites.centers[s].distance_to(map.arrival_point(d)) > config.spawner_range,
						"%s: spawners don't start on arrival" % def.display_name)


func test_remove_camp_keeps_the_rest_and_frees_its_boss_quietly() -> void:
	var state := SwarmState.new(16, 4, 2)
	for k in 6:
		state.spawn(Vector2(k, 0.0), 0, 10.0, k % 2)
	state.make_boss(2, 1)
	var removed := state.remove_camp(0)
	check_eq(removed, 3, "camp 0's members left")
	check_eq(state.count, 3, "camp 1 stays")
	for i in state.count:
		check_eq(state.camp_ids[i], 1, "only camp 1 left")
	check_eq(state.boss_index[1], -1, "the boss slot is empty")
	check_eq(state.boss_despawned[1], 1, "flagged as gone, not killed")


func test_camps_stream_in_near_the_player_and_out_when_far() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var swarm := _swarm()
	var director := CampDirector.new(config, swarm)
	director.use_sites(map.overworld_sites)
	var sites := map.overworld_sites
	var spot := map.region_center(3)  # a level-1 region
	_run(director, swarm, spot, 0.6)
	var expected := 0
	for s in sites.size():
		var near := sites.centers[s].distance_to(spot) <= config.spawn_radius
		check_eq(sites.state[s] == CampSites.State.SPAWNED, near, "site %d streams by distance" % s)
		if near:
			expected += sites.alive[s]
	check(expected > 0, "some camps came in")
	check_eq(swarm.enemy_count(), expected, "the swarm holds exactly the nearby camps")
	var awake := 0
	for i in swarm.state.count:
		var camp := swarm.state.camp_ids[i]
		if sites.centers[camp].distance_to(spot) > config.aggro_radius + 2.0:
			awake += swarm.state.awake[i]
	check_eq(awake, 0, "streamed-in camps out of aggro range sleep")
	# Walk to the far corner: those camps leave, others come in.
	var far := map.region_center(8)
	_run(director, swarm, far, 0.6)
	for s in sites.size():
		if sites.centers[s].distance_to(far) > config.despawn_radius:
			check(sites.state[s] != CampSites.State.SPAWNED, "far site %d left" % s)
	swarm.free()


func test_a_cleared_camp_comes_back_after_its_timer() -> void:
	var config := _config().duplicate() as WorldConfig
	config.camp_respawn_time = 1.0
	var map := WorldMap.new(config)
	var swarm := _swarm()
	var director := CampDirector.new(config, swarm)
	director.use_sites(map.overworld_sites)
	var sites := map.overworld_sites
	var camp := 0
	var spot := sites.centers[camp]
	_run(director, swarm, spot, 0.4)
	check_eq(sites.state[camp], CampSites.State.SPAWNED, "camp is in")
	for i in swarm.state.count:
		if swarm.state.camp_ids[i] == camp:
			swarm.state.health[i] = 0.0
	_run(director, swarm, spot, 0.2)
	check_eq(sites.state[camp], CampSites.State.CLEARED, "camp cleared")
	_run(director, swarm, spot, 1.5)
	check_eq(sites.state[camp], CampSites.State.CLEARED, "not back while the player stands on it")
	var aside := spot + Vector2(config.respawn_min_distance + 5.0, 0.0)
	_run(director, swarm, aside, 0.6)
	check_eq(sites.state[camp], CampSites.State.SPAWNED, "back once the player steps away")
	swarm.free()


func test_spawners_refill_while_the_player_is_near() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var swarm := _swarm()
	swarm.set_bounds(map.half_extent(0))
	swarm.set_layout(map.layouts[0], config.dungeon_chase_distance)
	var director := CampDirector.new(config, swarm)
	director.use_sites(map.dungeon_sites[0])
	var sites := map.dungeon_sites[0]
	var spawner := -1
	for s in sites.size():
		if sites.is_spawner[s] != 0:
			spawner = s
			break
	var spot := sites.centers[spawner] + Vector2(-4.0, 0.0)
	_run(director, swarm, spot, 0.6)
	var count := sites.alive[spawner]
	check(count >= 4, "a spawner adds monsters steadily (%d)" % count)
	for i in swarm.state.count:
		if swarm.state.camp_ids[i] == spawner:
			check_eq(swarm.state.awake[i], 1, "spawner monsters come awake")
			swarm.state.health[i] = 0.0
	_run(director, swarm, spot, 0.3)
	check_eq(sites.state[spawner], CampSites.State.SPAWNED, "a spawner never clears")
	check(sites.alive[spawner] >= 1, "and starts refilling at once (%d)" % sites.alive[spawner])
	swarm.free()


func test_dungeon_camps_come_back_at_once() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var swarm := _swarm()
	swarm.set_bounds(map.half_extent(0))
	swarm.set_layout(map.layouts[0], config.dungeon_chase_distance)
	var director := CampDirector.new(config, swarm)
	var sites := map.dungeon_sites[0]
	director.use_sites(sites)
	var camp := -1
	for s in sites.size():
		if sites.is_spawner[s] == 0:
			camp = s
			break
	check_near(sites.respawn_time[camp], 0.0, 0.0001, "dungeon camps respawn instantly")
	var spot := sites.centers[camp]
	var cleared: Array[int] = []
	director.camp_cleared.connect(func(s: int, _at: Vector2, _level: int, _boss: bool) -> void:
		cleared.append(s))
	_run(director, swarm, spot, 0.4)
	for i in swarm.state.count:
		if swarm.state.camp_ids[i] == camp:
			swarm.state.health[i] = 0.0
	_run(director, swarm, spot, 0.5)
	check(cleared.has(camp), "camp cleared")
	check_eq(sites.state[camp], CampSites.State.SPAWNED, "back while the player stands on it")
	check(sites.alive[camp] > 0, "with monsters (%d)" % sites.alive[camp])
	swarm.free()


func test_dungeon_is_a_hallway_with_rooms_both_sides_getting_deeper() -> void:
	var config := _config()
	var def := config.dungeons[0]
	var layout := DungeonLayout.new(def)
	check_eq(layout.rooms.size(), def.rooms_per_side * 2 + 1, "side rooms plus the boss room")
	var map := WorldMap.new(config)
	check_eq(layout.room_at(map.arrival_point(0)), 0, "the player arrives in the hallway")
	var left := 0
	var right := 0
	for room in layout.rooms.size():
		var center := layout.room_center(room)
		check_eq(layout.room_at(center), room + 1, "room %d's middle is in it" % room)
		check_eq(layout.room_at(layout.doors[room]), 0, "room %d's door opens to the hallway" % room)
		if room == layout.boss_room:
			check(center.y < layout.hallway.position.y, "the boss room is past the hallway's end")
			continue
		if center.x < 0.0:
			left += 1
		else:
			right += 1
		# Deeper rooms lie further from the entrance (+Z).
		for other in layout.rooms.size():
			if other != layout.boss_room and layout.depths[other] > layout.depths[room]:
				check(layout.room_center(other).y < center.y, "deeper is further in")
	check_eq(left, def.rooms_per_side, "rooms on the left")
	check_eq(right, def.rooms_per_side, "rooms on the right")
	# A wall stands between the hallway and a room away from its door.
	var room0 := layout.rooms[0]
	var beside := Vector2(layout.doors[0].x, room0.position.y + 1.0)
	check_eq(layout.room_at(beside), -1, "wall beside the door")
	check(layout.half_extent() <= 64.0, "fits the flow field's grid")


func test_monsters_route_through_doors() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var layout := map.layouts[0]
	var flow := FlowField.new(64.0, 2.0)
	flow.set_rooms(layout.rasterize(flow.origin, flow.cols, flow.rows, flow.cell_size),
			layout.door_points())
	# Player in room 0; a monster in room 2 heads for room 2's door first.
	var player := layout.room_center(0)
	flow.update(player)
	var monster := layout.room_center(2)
	var dir := flow.directions[flow.cell_index(monster)]
	var to_door := (layout.doors[2] - monster).normalized()
	check(dir.dot(to_door) > 0.95, "a monster in another room heads for its door (%s)" % dir)
	var in_hall := Vector2(0.0, layout.room_center(3).y)
	var hall_dir := flow.directions[flow.cell_index(in_hall)]
	check(hall_dir.dot((layout.doors[0] - in_hall).normalized()) > 0.95,
			"in the hallway it heads for the player's room's door")
	check(flow.is_wall(Vector2(layout.doors[0].x, layout.rooms[0].position.y + 1.0)),
			"walls are blocked")
	check(not flow.is_wall(player), "floor isn't")


func test_deeper_rooms_hold_higher_level_camps() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var sites := map.dungeon_sites[0]
	var def := config.dungeons[0]
	for s in sites.size():
		check_eq(sites.levels[s], def.level + sites.depth[s] * def.depth_level_step,
				"site %d's level grows with depth" % s)
	var deepest := 0
	for s in sites.size():
		deepest = maxi(deepest, sites.depth[s])
	check(deepest >= def.rooms_per_side - 1, "camps reach the deep rooms (%d)" % deepest)
