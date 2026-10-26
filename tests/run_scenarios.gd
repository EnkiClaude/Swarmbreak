extends SceneTree
## Plays the real main scene headless with scripted input, so wiring, scene
## loading and per-frame code all run in the engine.
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_scenarios.gd

const MAIN_SCENE := "res://scenes/main.tscn"

var _failures: PackedStringArray = []
var _main: Node
var _swarm: SwarmManager
var _player: Player
var _effects: EffectSystem
var _touch: TouchControls
var _projectiles: ProjectileSystem


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	_swarm = _main.get_node("Swarm") as SwarmManager
	_player = _main.get_node("Player") as Player
	_effects = _main.get_node("Effects") as EffectSystem
	_touch = _main.get_node("TouchLayer/TouchControls") as TouchControls
	_projectiles = _main.get_node("Projectiles") as ProjectileSystem
	await _frames(5)

	_scenario("initial swarm spawns", _initial_swarm)
	await _scenario_async("player moves with move_right", _player_moves)
	await _scenario_async("debug_spawn adds a batch", _debug_spawn)
	await _scenario_async("swarm keeps out of the player", _swarm_keeps_distance)
	await _scenario_async("nova breaks a nearby pack", _nova_breaks_pack)
	await _scenario_async("bolts burst on enemies ahead", _bolts_hit)
	await _scenario_async("touch move stick moves the player", _touch_move)
	await _scenario_async("touch aim stick fires bolts", _touch_aim_fires)
	await _scenario_async("touch nova button casts the nova", _touch_nova)

	print("%d scenario checks failed" % _failures.size())
	for failure in _failures:
		print("FAIL " + failure)
	var code := 1 if not _failures.is_empty() else 0
	# Free the scene before quitting so teardown happens in a normal frame.
	_main.queue_free()
	await _frames(2)
	quit(code)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _scenario(title: String, body: Callable) -> void:
	print("RUN  " + title)
	body.call()


func _scenario_async(title: String, body: Callable) -> void:
	print("RUN  " + title)
	await body.call()


func _initial_swarm() -> void:
	_check(_swarm.enemy_count() == _swarm.config.initial_count,
			"expected %d enemies, got %d" % [_swarm.config.initial_count, _swarm.enemy_count()])


func _player_moves() -> void:
	var start := _player.position
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	var moved := _player.position.distance_to(start)
	_check(moved > 1.0, "player moved only %.2f m in 30 frames" % moved)


func _debug_spawn() -> void:
	var before := _swarm.enemy_count()
	var press := InputEventAction.new()
	press.action = "debug_spawn"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = "debug_spawn"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(1)
	var added := _swarm.enemy_count() - before
	_check(added == _swarm.config.debug_spawn_batch, "debug_spawn added %d enemies" % added)


func _swarm_keeps_distance() -> void:
	await _frames(300)
	var player_xz := _player.ground_position()
	var min_d: float = _player.config.radius + _swarm.config.enemy_types[0].body_radius - 0.05
	var inside := 0
	for i in _swarm.state.count:
		if _swarm.state.positions[i].distance_to(player_xz) < min_d:
			inside += 1
	_check(inside == 0, "%d enemies overlap the player after 300 frames" % inside)


## Clears the swarm and places a tight pack around a point.
func _place_pack(center: Vector2, radius: float, amount: int) -> void:
	_swarm.state.clear()
	for i in amount:
		var r := radius * sqrt(float(i + 1) / amount)
		_swarm.spawn_at(center + Vector2.from_angle(i * 2.39996) * r)


func _nova_breaks_pack() -> void:
	await _frames(70)  # let any earlier cooldown run out
	var nova: NovaConfig = _player.config.nova
	_place_pack(_player.ground_position(), nova.radius * 0.8, 150)
	var kills_before := _swarm.total_kills
	Input.action_press("attack_nova")
	await _frames(2)
	Input.action_release("attack_nova")
	var kills := _swarm.total_kills - kills_before
	_check(kills >= 100, "nova killed only %d of a 150 pack inside its radius" % kills)
	_check(_swarm.best_break >= kills, "best break recorded (%d)" % _swarm.best_break)
	_check(_effects.active_count() > 0, "death and nova effects are showing")
	await _frames(30)
	_check(_effects.active_count() == 0, "effects expire (%d left)" % _effects.active_count())


func _bolts_hit() -> void:
	var aim := Vector2(_player.aim_direction.x, _player.aim_direction.z)
	_place_pack(_player.ground_position() + aim * 8.0, 1.5, 40)
	var kills_before := _swarm.total_kills
	Input.action_press("attack_fire")
	await _frames(90)
	Input.action_release("attack_fire")
	var kills := _swarm.total_kills - kills_before
	_check(kills > 0, "bolts killed nothing in a pack 8 m ahead")


func _touch_move() -> void:
	_touch.set_active(true)
	var start := _player.position
	var at := _touch.size * Vector2(0.2, 0.7)
	_touch.handle_touch(0, at, true)
	_touch.handle_drag(0, at + Vector2(100.0, 0.0))
	await _frames(30)
	_touch.handle_touch(0, at + Vector2(100.0, 0.0), false)
	var moved := _player.position.distance_to(start)
	_check(moved > 1.0, "touch stick moved the player only %.2f m" % moved)
	_check(Input.get_action_strength("move_right") == 0.0, "move released after lifting the thumb")


func _touch_aim_fires() -> void:
	var fired_before := _projectiles.fired_total
	var at := _touch.size * Vector2(0.8, 0.7)
	_touch.handle_touch(1, at, true)
	_touch.handle_drag(1, at + Vector2(0.0, -100.0))
	await _frames(30)
	_touch.handle_touch(1, at, false)
	var fired := _projectiles.fired_total - fired_before
	_check(fired >= 2, "aiming with the touch stick fired %d bolts in half a second" % fired)
	await _frames(10)
	var after := _projectiles.fired_total
	await _frames(20)
	_check(_projectiles.fired_total == after, "firing stops after lifting the thumb")


func _touch_nova() -> void:
	await _frames(80)  # nova cooldown
	_place_pack(_player.ground_position(), 4.0, 60)
	var kills_before := _swarm.total_kills
	var button := _touch.size * _touch.config.nova_button_position
	_touch.handle_touch(2, button, true)
	await _frames(2)
	_touch.handle_touch(2, button, false)
	await _frames(1)  # button releases go through the input queue
	var kills := _swarm.total_kills - kills_before
	_check(kills >= 40, "touch nova killed only %d of 60 nearby" % kills)
	_check(not Input.is_action_pressed("attack_nova"), "nova released after lifting the finger")
