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
var _feedback: CombatFeedback
var _popup: BreakPopup
var _corpses: CorpseSystem
var _camera: CameraRig


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
	_feedback = _main.get_node("Feedback") as CombatFeedback
	_popup = _main.get_node("BreakPopup") as BreakPopup
	_corpses = _main.get_node("Corpses") as CorpseSystem
	_camera = _main.get_node("CameraRig") as CameraRig
	await _frames(5)

	_scenario("initial swarm spawns", _initial_swarm)
	await _scenario_async("player moves with move_right", _player_moves)
	await _scenario_async("debug_spawn adds a batch", _debug_spawn)
	await _scenario_async("swarm keeps out of the player", _swarm_keeps_distance)
	await _scenario_async("nova breaks a nearby pack", _nova_breaks_pack)
	await _scenario_async("a big break freezes, shakes, pops up and flings corpses", _break_feedback)
	await _scenario_async("bolts burst on enemies ahead", _bolts_hit)
	await _scenario_async("touch move stick moves the player", _touch_move)
	await _scenario_async("touch FIRE stick fires and aims", _touch_fire)
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


func _touch_fire() -> void:
	await _frames(20)
	var fired_before := _projectiles.fired_total
	var center := _touch.size * _touch.config.fire_button_position
	_touch.handle_touch(1, center, true)
	_touch.handle_drag(1, center + Vector2(0.0, -100.0))
	await _frames(30)
	_touch.handle_touch(1, center, false)
	var fired := _projectiles.fired_total - fired_before
	_check(fired >= 2, "holding FIRE fired %d bolts in half a second" % fired)
	var aim := _player.aim_direction
	var screen_up := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, _camera.yaw())
	_check(aim.dot(screen_up) > 0.9, "dragging FIRE up aims screen-up (aim %s)" % aim)
	await _frames(10)
	var after := _projectiles.fired_total
	await _frames(20)
	_check(_projectiles.fired_total == after, "firing stops after lifting the thumb")
	var right_half := _touch.size * Vector2(0.7, 0.4)
	_touch.handle_touch(3, right_half, true)
	await _frames(20)
	_touch.handle_touch(3, right_half, false)
	_check(_projectiles.fired_total == after, "touching empty screen does not fire")


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


func _break_feedback() -> void:
	await _frames(80)  # nova cooldown
	_place_pack(_player.ground_position(), 4.5, 120)
	var trauma_before := _camera.trauma
	Input.action_press("attack_nova")
	await _frames(1)
	Input.action_release("attack_nova")
	_check(_feedback.hitstop_remaining > 0.0, "a 120-enemy break starts a freeze-frame")
	_check(_camera.trauma > trauma_before + 0.3, "the camera shakes (trauma %.2f)" % _camera.trauma)
	_check(_popup.is_showing(), "the BREAK popup shows")
	_check(_corpses.active_count() >= 100, "corpses fly (%d)" % _corpses.active_count())
	var frozen_at := _player.position
	Input.action_press("move_right")
	await _frames(3)
	_check(_player.position == frozen_at, "the player is frozen during hit-stop")
	await _frames(20)
	Input.action_release("move_right")
	_check(_player.position != frozen_at, "the game resumes after hit-stop")
	await _frames(70)
	_check(_corpses.active_count() == 0, "corpses clear away (%d left)" % _corpses.active_count())
	_check(not _popup.is_showing(), "the popup fades out")
