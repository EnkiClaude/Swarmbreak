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
			check(absf(at.x) < def.half_extent and absf(at.y) < def.half_extent, "inside the hall")
			check(at.distance_to(map.arrival_point(d)) >= config.keep_clear_radius * 0.99,
					"%s: no camp where the player arrives" % def.display_name)
			check_eq(sites.levels[s], def.level, "dungeon level")
			spawners += sites.is_spawner[s]
			bosses += sites.has_boss[s]
		check_eq(spawners, def.spawner_count, "%s spawners" % def.display_name)
		check_eq(bosses, 1, "%s has a boss" % def.display_name)
		# Arriving must not land on the way-out gate, or leaving bounce back in.
		check(map.arrival_point(d).distance_to(map.exit_position(d)) > config.gate_radius,
				"arrival is clear of the exit")
		check(map.gate_exit_point(d).distance_to(map.gate_position(d)) > config.gate_radius,
				"leaving is clear of the entrance")


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
	swarm.set_bounds(config.dungeons[0].half_extent)
	var director := CampDirector.new(config, swarm)
	director.use_sites(map.dungeon_sites[0])
	var sites := map.dungeon_sites[0]
	var spawner := -1
	for s in sites.size():
		if sites.is_spawner[s] != 0:
			spawner = s
			break
	var spot := sites.centers[spawner] + Vector2(-4.0, 0.0)
	var interval := sites.spawn_interval[spawner]
	_run(director, swarm, spot, interval * 6.0)
	var count := sites.alive[spawner]
	check(count >= 4, "a spawner adds monsters steadily (%d)" % count)
	for i in swarm.state.count:
		if swarm.state.camp_ids[i] == spawner:
			check_eq(swarm.state.awake[i], 1, "spawner monsters come awake")
			swarm.state.health[i] = 0.0
	_run(director, swarm, spot, interval * 3.0)
	check_eq(sites.state[spawner], CampSites.State.SPAWNED, "a spawner never clears")
	check(sites.alive[spawner] >= 1, "and starts refilling at once (%d)" % sites.alive[spawner])
	swarm.free()
