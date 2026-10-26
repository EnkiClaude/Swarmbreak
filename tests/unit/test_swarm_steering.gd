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
		grid = SpatialHash.new(HALF, 1.0, 64)
		flow = FlowField.new(HALF, 2.0)
		steering = SwarmSteering.new(state, grid, flow, SwarmTypeTable.new(types), 3.0, HALF)

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
