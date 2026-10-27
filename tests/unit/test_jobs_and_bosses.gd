extends TestSuite


func _jobs() -> JobTree:
	return load("res://data/rpg/jobs.tres") as JobTree


func _skills() -> SkillTree:
	return load("res://data/rpg/skills.tres") as SkillTree


func _progression() -> ProgressionConfig:
	return load("res://data/rpg/progression.tres") as ProgressionConfig


func _progress() -> PlayerProgress:
	return PlayerProgress.new(_progression(), _skills())


func test_job_unlocks_and_promotes_at_their_levels() -> void:
	var jobs := _jobs()
	var progress := _progress()
	check_eq(jobs.jobs.size(), 3, "three paths")
	check(not progress.choose_job(jobs, 0), "locked before the unlock level")
	progress.level = jobs.unlock_level
	check(progress.choose_job(jobs, 1), "chosen at the unlock level")
	check(not progress.choose_job(jobs, 2), "the choice is permanent")
	check_eq(progress.job_rank, 1, "rank 1")
	check(not progress.promote_if_ready(jobs), "no promotion yet")
	progress.level = jobs.rank2_level
	check(progress.promote_if_ready(jobs), "promoted at rank-2 level")
	check_eq(progress.job_title(jobs), jobs.jobs[1].rank2_name, "promoted title")


func test_job_perks_feed_stats() -> void:
	var jobs := _jobs()
	var progress := _progress()
	var inventory := Inventory.new(4)
	var stats := PlayerStats.new(progress, _skills(), inventory, _progression(), jobs)
	check(stats.perks == null, "no perks without a job")
	progress.level = jobs.unlock_level
	progress.choose_job(jobs, 0)
	stats.recompute()
	check(stats.perks != null and stats.perks.nova_aftershocks >= 1, "Stormcaller aftershocks")
	check(stats.value(PlayerStat.Id.NOVA_DAMAGE) > 0.0, "job stat bonus applied")


func test_boss_index_follows_compaction() -> void:
	var state := SwarmState.new(16, 2, 2)
	for i in 6:
		state.spawn(Vector2(i, 0), 0, 10.0)
	state.make_boss(4, 0)
	state.make_boss(5, 1)
	state.health[1] = 0.0
	state.health[2] = 0.0
	state.remove_dead()
	check_eq(state.boss_index[0], 2, "boss 0 moved down to index 2")
	check_eq(state.positions[state.boss_index[0]], Vector2(4, 0), "same enemy")
	state.health[state.boss_index[1]] = 0.0
	state.remove_dead()
	check_eq(state.boss_index[1], -1, "dead boss slot is cleared")
	state.despawn(state.boss_index[0])
	check_eq(state.boss_index[0], -1, "despawned boss slot is cleared")


func test_knockback_resist_and_marks() -> void:
	var light := EnemyType.new()
	var heavy := EnemyType.new()
	heavy.knockback_resist = 0.9
	var types: Array[EnemyType] = [light, heavy]
	var state := SwarmState.new(8)
	var grid := SpatialHash.new(1.0, 256, 8)
	var combat := SwarmCombat.new(state, grid, SwarmTypeTable.new(types))
	state.spawn(Vector2(1, 0), 0, 100.0)
	state.spawn(Vector2(-1, 0), 1, 100.0)
	state.spawn(Vector2(0, 1), 0, 100.0)
	state.mark_until[2] = 10.0
	grid.build(state.positions, state.count)
	combat.damage_circle(Vector2.ZERO, 2.0, 10.0, 10.0, 0.0, 1.0, 0.5)
	check(state.velocities[0].length() > state.velocities[1].length() * 5.0,
			"heavy enemies barely move")
	check_near(state.health[0], 90.0, 0.001, "normal damage")
	check_near(state.health[2], 85.0, 0.001, "marked enemy takes 50% more")


func test_stunned_enemies_hold_still() -> void:
	var enemy := EnemyType.new()
	var types: Array[EnemyType] = [enemy]
	var state := SwarmState.new(8)
	var grid := SpatialHash.new(1.0, 256, 8)
	var flow := FlowField.new(10.0, 2.0)
	var steering := SwarmSteering.new(state, grid, flow, SwarmTypeTable.new(types), 3.0, 10.0, 8)
	state.spawn(Vector2(5, 0), 0)
	state.stun_until[0] = 100.0
	for f in 60:
		flow.update(Vector2(-5, 0))
		grid.build(state.positions, state.count)
		steering.step(Vector2(-5, 0), 0.45, 1.0 / 60.0, 1.0)
	check(state.positions[0].distance_to(Vector2(5, 0)) < 0.01, "didn't move while stunned")


func test_bolts_keep_pierce_counts() -> void:
	var pool := ProjectilePool.new(4)
	pool.spawn(Vector2.ZERO, Vector2.RIGHT, 2)
	pool.spawn(Vector2.ONE, Vector2.RIGHT, 0)
	pool.remove(0)
	check_eq(pool.pierce_left[0], 0, "swap-remove moves pierce with the bolt")
