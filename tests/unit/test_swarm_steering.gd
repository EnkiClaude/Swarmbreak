extends TestSuite

const HALF := 10.0
const PLAYER_RADIUS := 0.45
const DT := 1.0 / 60.0


class Rig:
	var state: SwarmState
	var grid: SpatialHash
	var flow: FlowField
	var steering: SwarmSteering
	var enemy: EnemyType

	func _init() -> void:
		enemy = EnemyType.new()
		var types: Array[EnemyType] = [enemy]
		state = SwarmState.new(64)
		grid = SpatialHash.new(1.0, 1024, 64)
		flow = FlowField.new(HALF, 2.0)
		steering = SwarmSteering.new(state, grid, flow, SwarmTypeTable.new(types), 3.0, HALF, 8, 3)

	func run(player: Vector2, frames: int) -> void:
		for f in frames:
			flow.update(player)
			grid.build(state.positions, state.count)
			steering.step(player, PLAYER_RADIUS, DT)


func test_enemies_approach_player() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(8, 8), 0)
	var player := Vector2(-8, -8)
	var before := rig.state.positions[0].distance_to(player)
	rig.run(player, 120)
	var after := rig.state.positions[0].distance_to(player)
	check(before - after > 5.0, "moved toward player (%.2f -> %.2f)" % [before, after])


func test_stacked_enemies_separate() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(2, 2), 0)
	rig.state.spawn(Vector2(2, 2), 0)
	rig.run(Vector2(-8, -8), 60)
	var gap := rig.state.positions[0].distance_to(rig.state.positions[1])
	check(gap > 0.3, "stacked pair pushed apart (gap %.3f)" % gap)


func test_enemies_stay_out_of_player() -> void:
	var rig := Rig.new()
	for i in 20:
		rig.state.spawn(Vector2.from_angle(i * 0.3) * 0.5, 0)
	rig.run(Vector2.ZERO, 120)
	var min_d := PLAYER_RADIUS + rig.enemy.body_radius - 0.01
	for i in rig.state.count:
		var d := rig.state.positions[i].length()
		if d < min_d:
			failures.append("enemy %d inside player at %.3f" % [i, d])


func test_positions_clamped_to_arena() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(HALF + 5.0, -HALF - 5.0), 0)
	rig.run(Vector2(HALF + 20.0, 0), 1)
	var p := rig.state.positions[0]
	check(absf(p.x) <= HALF and absf(p.y) <= HALF, "clamped inside arena (got %s)" % p)


func test_sleeping_enemies_stay_put() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(6, 6), 0, 20.0, 0, false)
	rig.state.velocities[0] = Vector2(3, 0)  # knockback from a hit
	rig.run(Vector2(-6, -6), 120)
	var p := rig.state.positions[0]
	check(p.distance_to(Vector2(6, 6)) < 2.0, "did not chase the player (at %s)" % p)
	check(rig.state.velocities[0].length() < 0.01, "knockback bled off")


func test_touching_enemies_hurt_up_to_the_attacker_cap() -> void:
	var rig := Rig.new()
	for i in 6:
		rig.state.spawn(Vector2.from_angle(i * TAU / 6.0) * 0.8, 0, 20.0)
	rig.run(Vector2.ZERO, 30)
	check_eq(rig.steering.contact_count, 6, "all six touch the player")
	check_near(rig.steering.contact_dps, 3.0 * rig.enemy.contact_dps, 0.001,
			"damage capped at 3 attackers")


func test_lure_boost_speeds_up_chasers() -> void:
	var slow := Rig.new()
	var fast := Rig.new()
	slow.state.spawn(Vector2(9, 0), 0)
	fast.state.spawn(Vector2(9, 0), 0)
	fast.state.boost_until[0] = 100.0
	for f in 30:
		for rig in [slow, fast]:
			rig.flow.update(Vector2(-9, 0))
			rig.grid.build(rig.state.positions, rig.state.count)
		slow.steering.step(Vector2(-9, 0), PLAYER_RADIUS, DT, 1.0, 2.0)
		fast.steering.step(Vector2(-9, 0), PLAYER_RADIUS, DT, 1.0, 2.0)
	check(fast.state.positions[0].x < slow.state.positions[0].x - 1.0, "boosted enemy got further")
