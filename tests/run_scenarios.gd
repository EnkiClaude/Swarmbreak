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
var _zone: ZoneDirector


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
	await _frames(5)  # nodes finish _ready during the first frames
	_zone = _main.get("zone") as ZoneDirector
	_god_mode(true)

	_scenario("the zone starts with sleeping camps", _zone_starts_asleep)
	await _scenario_async("a camp wakes when the player comes near", _camp_wakes_on_approach)
	await _scenario_async("lure wakes camps in range and hurries them", _lure_wakes_camps)
	await _scenario_async("clearing a camp drops loot you can pick up", _camp_drops_loot)
	await _scenario_async("the character screen pauses and spends points", _character_menu)
	await _scenario_async("player moves with move_right", _player_moves)
	await _scenario_async("debug_spawn adds a batch", _debug_spawn)
	await _scenario_async("swarm keeps out of the player", _swarm_keeps_distance)
	await _scenario_async("nova breaks a nearby pack", _nova_breaks_pack)
	await _scenario_async("a big break freezes, shakes, pops up and flings corpses", _break_feedback)
	await _scenario_async("kills give XP and level-ups refill and grant points", _xp_and_levels)
	await _scenario_async("bolts burst on enemies ahead", _bolts_hit)
	await _scenario_async("touch move stick moves the player", _touch_move)
	await _scenario_async("touch FIRE stick fires and aims", _touch_fire)
	await _scenario_async("touch nova button casts the nova", _touch_nova)
	await _scenario_async("enemies hurt the player; dodging grants i-frames", _damage_and_dodge)
	await _scenario_async("without mana the nova does not cast", _nova_needs_mana)
	await _scenario_async("dying restarts the zone", _death_restarts_zone)
	await _scenario_async("clearing every camp starts the next zone", _clear_advances_zone)

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


## Invulnerable so long scenarios can't kill the player by accident.
func _god_mode(on: bool) -> void:
	_player.vitals.invulnerable_until = 1.0e9 if on else 0.0


func _refill() -> void:
	_player.vitals.mana = _player.vitals.max_mana
	_player.vitals.health = _player.vitals.max_health


func _zone_starts_asleep() -> void:
	_check(_zone.level == 1, "starts at zone 1")
	_check(_zone.camp_centers.size() >= 10, "%d camps placed" % _zone.camp_centers.size())
	_check(_swarm.enemy_count() == _zone.alive_total,
			"%d enemies vs %d camp members" % [_swarm.enemy_count(), _zone.alive_total])
	var awake := 0
	for i in _swarm.state.count:
		awake += _swarm.state.awake[i]
	_check(awake == 0, "%d enemies awake at the start" % awake)
	for c in _zone.camp_centers:
		if c.length() < _zone_config().safe_start_radius:
			_check(false, "camp at %s is inside the safe start area" % c)


func _zone_config() -> ZoneConfig:
	return _main.get("zone_config") as ZoneConfig


func _teleport(to: Vector2) -> void:
	_player.position = Vector3(to.x, 0.0, to.y)


func _camp_awake_members(camp: int) -> int:
	var n := 0
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == camp and _swarm.state.awake[i] != 0:
			n += 1
	return n


func _camp_wakes_on_approach() -> void:
	var center: Vector2 = _zone.camp_centers[0]
	var away := (Vector2.ZERO - center).normalized()
	var aggro := _zone_config().aggro_radius
	_teleport(center + away * (aggro + 4.0))
	await _frames(5)
	_check(_zone.camp_awake[0] == 0, "camp 0 stays asleep outside aggro range")
	_teleport(center + away * (aggro - 2.0))
	await _frames(3)
	_check(_zone.camp_awake[0] == 1, "camp 0 wakes inside aggro range")
	_check(_camp_awake_members(0) == _zone.camp_alive[0],
			"all %d members of camp 0 woke (%d)" % [_zone.camp_alive[0], _camp_awake_members(0)])
	_teleport(Vector2.ZERO)


func _lure_wakes_camps() -> void:
	var target := -1
	for camp in _zone.camp_centers.size():
		if _zone.camp_awake[camp] == 0:
			target = camp
			break
	_check(target >= 0, "a sleeping camp to lure")
	if target < 0:
		return
	var lure: LureConfig = _player.config.lure
	var center: Vector2 = _zone.camp_centers[target]
	var spot := center + (Vector2.ZERO - center).normalized() * (_zone_config().aggro_radius + 6.0)
	_teleport(spot)
	await _frames(2)
	_check(_zone.camp_awake[target] == 0, "camp still asleep before the lure")
	_refill()
	Input.action_press("skill_lure")
	await _frames(1)
	Input.action_release("skill_lure")
	await _frames(1)
	_check(_zone.camp_awake[target] == 1, "lure woke camp %d from %.0f m" % [
			target, spot.distance_to(center)])
	var spent := _player.vitals.max_mana - _player.vitals.mana
	_check(spent > lure.mana_cost * 0.8, "lure cost mana (%.1f)" % spent)
	var boosted := 0
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == target and _swarm.state.boost_until[i] > _swarm.now():
			boosted += 1
	_check(boosted > 0, "lured enemies are sped up")
	_teleport(Vector2.ZERO)


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
	_refill()
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
	_refill()
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
	_refill()
	_place_pack(_player.ground_position(), 4.5, 120)
	var trauma_before := _camera.trauma
	Input.action_press("attack_nova")
	await _frames(1)
	Input.action_release("attack_nova")
	_check(_feedback.hitstop_remaining > 0.0, "a 120-enemy break starts a freeze-frame")
	_check(_camera.trauma > trauma_before + 0.3, "the camera shakes (trauma %.2f)" % _camera.trauma)
	_check(_popup.is_showing(), "the BREAK popup shows")
	await _frames(1)
	_check(_popup.is_showing(), "the BREAK popup is still up the frame after (not replaced)")
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


func _damage_and_dodge() -> void:
	_refill()
	_god_mode(false)
	_place_pack(_player.ground_position(), 1.6, 24)
	await _frames(30)
	var vitals := _player.vitals
	_check(vitals.health < vitals.max_health - 5.0, "touching enemies hurt (%.1f hp)" % vitals.health)
	Input.action_press("dodge")
	await _frames(1)
	Input.action_release("dodge")
	_check(_player.is_dashing(), "dodge starts a dash")
	var during := vitals.health
	await _frames(5)
	_check(vitals.health >= during, "no damage during the dodge (%.2f -> %.2f)" % [
			during, vitals.health])
	_swarm.state.clear()
	_refill()
	_god_mode(true)


func _nova_needs_mana() -> void:
	await _frames(80)  # nova cooldown
	_place_pack(_player.ground_position(), 4.0, 40)
	_player.vitals.mana = 0.0
	var kills_before := _swarm.total_kills
	Input.action_press("attack_nova")
	await _frames(2)
	Input.action_release("attack_nova")
	_check(_swarm.total_kills == kills_before, "no nova without mana")
	_refill()


func _death_restarts_zone() -> void:
	var level := _zone.level
	_god_mode(false)
	_player.vitals.health = 1.0
	_place_pack(_player.ground_position(), 1.6, 24)
	await _frames(20)
	_check(_player.vitals.is_dead(), "player died to the pack")
	_check(_popup.is_showing(), "death message shows")
	await _frames(roundi(_player.config.respawn_delay * 60.0) + 10)
	_check(not _player.vitals.is_dead(), "player is back after the respawn delay")
	_check(_zone.level == level, "same zone level after dying")
	_check(_swarm.enemy_count() == _zone.alive_total and _zone.alive_total > 0,
			"zone camps respawned (%d)" % _swarm.enemy_count())
	_god_mode(true)


func _clear_advances_zone() -> void:
	var level := _zone.level
	var camps := _zone.camp_centers.size()
	for i in _swarm.state.count:
		_swarm.state.health[i] = 0.0
	await _frames(3)
	_check(_zone.is_cleared(), "zone cleared once every camp member is dead")
	await _frames(150)
	_check(_zone.level == level + 1, "moved on to zone %d (at %d)" % [level + 1, _zone.level])
	_check(_zone.camp_centers.size() > camps, "the next zone has more camps (%d > %d)" % [
			_zone.camp_centers.size(), camps])


func _main_var(name: String) -> Variant:
	return _main.get(name)


func _camp_drops_loot() -> void:
	var loot := _main.get_node("Loot") as LootSystem
	var inventory := _main_var("inventory") as Inventory
	var camp := -1
	for c in _zone.camp_centers.size():
		if _zone.camp_alive[c] > 0:
			camp = c
			break
	_check(camp >= 0, "a camp to clear")
	if camp < 0:
		return
	var at := Vector2.ZERO
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == camp:
			_swarm.state.health[i] = 0.0
			at = _swarm.state.positions[i]
	var before := loot.ground_count()
	await _frames(2)
	_check(_zone.camp_alive[camp] == 0, "camp %d cleared" % camp)
	var dropped := loot.ground_count() - before
	_check(dropped >= 1, "camp dropped %d items" % dropped)
	var held := inventory.backpack.size()
	for item in inventory.equipped:
		if item != null:
			held += 1
	_teleport(at)
	await _frames(40)
	var now_held := inventory.backpack.size()
	for item in inventory.equipped:
		if item != null:
			now_held += 1
	_check(now_held >= held + dropped, "walked over the loot and picked up %d" % (now_held - held))
	_check(loot.ground_count() == before, "nothing left on the ground")
	_teleport(Vector2.ZERO)


func _character_menu() -> void:
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	var progress := _main_var("progress") as PlayerProgress
	var stats := _main_var("stats") as PlayerStats
	var press := InputEventAction.new()
	press.action = "character_menu"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	_check(menu.is_open(), "menu opens")
	_check(paused, "game pauses")
	var t := _swarm.now()
	await _frames(10)
	_check(_swarm.now() == t, "simulation stands still while paused")
	var tree := _main_var("skill_tree") as SkillTree
	var shockwave := -1
	for k in tree.skills.size():
		if tree.skills[k].stat == PlayerStat.Id.NOVA_DAMAGE:
			shockwave = k
	progress.skill_points += 1
	var before := stats.value(PlayerStat.Id.NOVA_DAMAGE)
	menu.rank_up(shockwave)
	_check(stats.value(PlayerStat.Id.NOVA_DAMAGE) > before, "spending a point raised nova damage")
	menu.close()
	await _frames(2)
	_check(not paused, "closing unpauses")
	_check(not Input.emulate_mouse_from_touch, "touch is touch again after closing")


func _xp_and_levels() -> void:
	var progress := _main_var("progress") as PlayerProgress
	var gained_before := progress.xp
	var level_before := progress.level
	await _frames(80)
	_refill()
	_place_pack(_player.ground_position(), 4.0, 50)
	Input.action_press("attack_nova")
	await _frames(2)
	Input.action_release("attack_nova")
	_check(progress.level > level_before or progress.xp > gained_before, "kills gave XP")
	var level := progress.level
	var points := progress.skill_points
	_player.vitals.health = 10.0
	progress.add_xp(progress.xp_to_next())
	await _frames(2)
	_check(progress.level == level + 1, "levelled up")
	_check(progress.skill_points == points + 1, "got a skill point")
	_check(_player.vitals.health == _player.vitals.max_health, "level-up refills health")
