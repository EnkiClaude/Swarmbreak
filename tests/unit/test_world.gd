extends TestSuite

const WORLD := "res://data/world/world.tres"


func _config() -> WorldConfig:
	return load(WORLD) as WorldConfig


## A real swarm (headless), so camps can stream in and out of it.
func _swarm() -> SwarmManager:
	var swarm := SwarmManager.new()
	swarm.config = load("res://data/swarm.tres") as SwarmConfig
	swarm.setup(72.0, null, null, 128, 8)
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
		check_eq(spawners, def.arena_spawners + def.boss_room_spawners, "%s spawners" %
				def.display_name)
		check_eq(sites.size(), def.arena_camps + 1 + def.boss_room_camps
				+ def.boss_room_spawners, "%s: arena camps, the boss and its room's" %
				def.display_name)
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
	# A copy with a spawner in the arena (the shipped dungeons may have none).
	var config := _config().duplicate(true) as WorldConfig
	config.dungeons[0].arena_spawners = 1
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


func test_dungeon_is_a_lobby_an_arena_and_a_boss_room() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	for d in config.dungeons.size():
		var layout := map.layouts[d]
		check_eq(layout.rooms.size(), 3, "lobby, arena and boss room")
		check_eq(layout.room_at(map.arrival_point(d)), DungeonLayout.LOBBY + 1,
				"the player arrives in the lobby")
		check_eq(layout.room_at(map.exit_position(d)), DungeonLayout.LOBBY + 1,
				"the exit is in the lobby")
		var lobby := layout.rooms[DungeonLayout.LOBBY]
		var arena := layout.rooms[DungeonLayout.ARENA]
		var boss := layout.rooms[layout.boss_room]
		check(arena.get_center().y < lobby.get_center().y, "the arena lies past the lobby")
		check(boss.get_center().y < arena.get_center().y, "and the boss room past the arena")
		check(arena.get_area() > lobby.get_area() * 4.0, "the arena is big and open")
		# Corridors join them: a straight walk north from the lobby stays on floor.
		var z := lobby.get_center().y
		while z > boss.get_center().y:
			check(layout.room_at(Vector2(0.0, z)) >= 0, "floor all the way north (z %.1f)" % z)
			z -= 1.0
		check_eq(layout.room_at(Vector2(lobby.end.x + 1.0, lobby.get_center().y)), -1,
				"walls beside the lobby")
		check(layout.half_extent() <= 72.0, "fits the flow field's grid")


func test_monsters_route_toward_their_rooms_door() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var layout := map.layouts[0]
	var flow := FlowField.new(72.0, 2.0)
	flow.set_rooms(layout.rasterize(flow.origin, flow.cols, flow.rows, flow.cell_size),
			layout.door_points())
	# Player in the lobby; a monster in the arena heads for the arena's door.
	var player := layout.room_center(DungeonLayout.LOBBY)
	flow.update(player)
	var monster := layout.room_center(DungeonLayout.ARENA) + Vector2(10.0, -8.0)
	var dir := flow.directions[flow.cell_index(monster)]
	var to_door := (layout.doors[DungeonLayout.ARENA] - monster).normalized()
	check(dir.dot(to_door) > 0.9, "a monster in the arena heads for its door (%s)" % dir)
	check(flow.is_wall(Vector2(layout.rooms[DungeonLayout.LOBBY].end.x + 1.0, player.y)),
			"walls are blocked")
	check(not flow.is_wall(player), "floor isn't")


func test_the_boss_room_is_harder_and_the_lobby_empty() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var sites := map.dungeon_sites[0]
	var def := config.dungeons[0]
	var layout := map.layouts[0]
	var homes := layout.homes_for(sites.centers)
	for s in sites.size():
		check(homes[s] != DungeonLayout.LOBBY + 1, "no camp in the lobby")
		check(homes[s] > 0, "every camp is in a room")
		var wanted: int = def.level
		if homes[s] == layout.boss_room + 1:
			wanted += def.depth_level_step
		check_eq(sites.levels[s], wanted, "site %d's level" % s)
	var in_arena := 0
	var in_boss := 0
	for s in sites.size():
		if homes[s] == DungeonLayout.ARENA + 1:
			in_arena += 1
		elif homes[s] == layout.boss_room + 1:
			in_boss += 1
	check_eq(in_arena, def.arena_camps, "camps spread over the arena")
	check_eq(in_boss, def.boss_room_camps + def.boss_room_spawners + 1, "and the boss room")


func test_room_monsters_stay_in_their_room() -> void:
	var config := _config()
	var map := WorldMap.new(config)
	var layout := map.layouts[0]
	var swarm := _swarm()
	swarm.set_bounds(layout.half_extent())
	# Camp 0 lives in the arena; camp 1 roams.
	var arena_id := DungeonLayout.ARENA + 1
	var homes := PackedInt32Array([arena_id, 0])
	swarm.set_layout(layout, 1.5, homes)
	var door := layout.doors[DungeonLayout.ARENA]
	var inside := door + Vector2(0.0, -4.0)
	var leashed := swarm.spawn_at(inside, 0, 0, true)
	var roamer := swarm.spawn_at(inside + Vector2(1.5, 0.0), 0, 1, true)
	check(leashed >= 0 and roamer >= 0, "spawned two monsters by the arena's door")
	# The player waits in the corridor outside: both chase.
	var player := door + Vector2(0.0, 8.0)
	for _n in 240:
		swarm.simulate(1.0 / 60.0, player, 0.5)
		swarm.resolve_deaths()
	var leashed_pos := swarm.state.positions[0]
	var free_pos := swarm.state.positions[1]
	if swarm.state.camp_ids[0] != 0:
		var swap := leashed_pos
		leashed_pos = free_pos
		free_pos = swap
	# Steering works on 2 m cells: judge by the cell each one stands in.
	check_eq(layout.room_at(_cell_center(leashed_pos)), arena_id,
			"the leashed one stays in its room (%s)" % leashed_pos)
	check(layout.room_at(_cell_center(free_pos)) != arena_id,
			"the free one walks out to the player (%s)" % free_pos)
	swarm.free()


func test_higher_level_dungeon_monsters_are_a_little_faster() -> void:
	var config := _config()
	var swarm := _swarm()
	var director := CampDirector.new(config, swarm)
	director.speed_by_level = false
	check_eq(director.speed_multiplier(40), 1.0, "open-world monsters keep their speed")
	director.speed_by_level = true
	check_eq(director.speed_multiplier(1), 1.0, "level 1 is the base speed")
	var mid := director.speed_multiplier(20)
	check(mid > 1.0 and mid < 1.3, "level 20 is a little faster (%.2f)" % mid)
	check(director.speed_multiplier(30) > mid, "and level 30 faster still")
	check_eq(director.speed_multiplier(500), config.dungeon_speed_max, "capped")
	# The steering uses it.
	var slow := swarm.spawn_at(Vector2(0.0, 10.0), 0, -1, true)
	var fast := swarm.spawn_at(Vector2(30.0, 10.0), 0, -1, true)
	swarm.state.speed_scale[fast] = 1.3
	for _n in 60:
		swarm.simulate(1.0 / 60.0, Vector2(15.0, -40.0), 0.5)
	check(swarm.state.velocities[fast].length() > swarm.state.velocities[slow].length() * 1.2,
			"a faster monster moves faster")
	swarm.free()


func test_a_thinned_camp_refills_without_being_cleared() -> void:
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
		if sites.is_spawner[s] == 0 and sites.has_boss[s] == 0:
			camp = s
			break
	check(sites.refill_time[camp] > 0.0, "dungeon camps refill")
	# Stand in the lobby, far enough not to wake it.
	var spot := map.arrival_point(0)
	_run(director, swarm, spot, 0.3)
	var full := sites.alive[camp]
	check(full > 4, "the camp is in (%d)" % full)
	var killed := 0
	for i in swarm.state.count:
		if swarm.state.camp_ids[i] == camp and killed * 2 < full:
			swarm.state.health[i] = 0.0
			killed += 1
	_run(director, swarm, spot, 0.2)
	var thinned := sites.alive[camp]
	check_eq(thinned, full - killed, "half of it died")
	check_eq(sites.state[camp], CampSites.State.SPAWNED, "not cleared")
	_run(director, swarm, spot, sites.refill_time[camp] * 3.5)
	check(sites.alive[camp] > thinned, "members come back on their own (%d -> %d)" %
			[thinned, sites.alive[camp]])
	check(sites.alive[camp] <= sites.sizes[camp], "never above its size")
	var members := 0
	for i in swarm.state.count:
		if swarm.state.camp_ids[i] == camp:
			members += 1
	check_eq(members, sites.alive[camp], "the count matches the swarm")
	swarm.free()


func test_frost_slows_enemies_it_reaches() -> void:
	var swarm := _swarm()
	var near := swarm.spawn_at(Vector2(0.0, 10.0), 0, -1, true)
	var far := swarm.spawn_at(Vector2(30.0, 10.0), 0, -1, true)
	swarm.simulate(1.0 / 60.0, Vector2(15.0, -40.0), 0.5)
	check_eq(swarm.slow_within(Vector2(0.0, 10.0), 3.0, 0.4, 2.0), 1, "only the near one is slowed")
	for _n in 60:
		swarm.simulate(1.0 / 60.0, Vector2(15.0, -40.0), 0.5)
	check(swarm.state.velocities[near].length() < swarm.state.velocities[far].length() * 0.6,
			"the slowed one moves slower")
	var nova := load("res://data/abilities/nova.tres") as NovaConfig
	check_eq(nova.knockback, 0.0, "the Frost Nova doesn't knock back")
	check(nova.slow_factor < 1.0 and nova.slow_duration > 0.0, "it slows instead")
	swarm.free()
