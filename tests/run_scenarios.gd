extends SceneTree
## Plays the real main scene headless with scripted input, so wiring, scene
## loading and per-frame code all run in the engine.
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_scenarios.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const SCENARIO_SAVE := "user://scenario_save.json"

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
var _world: WorldDirector
var _camps: CampDirector
var _slams_inside := 0
var _slams_outside := 0
var _slam_damage := 0.0


func _initialize() -> void:
	_run()


func _run() -> void:
	# Never touch a real save: use a scratch file, starting empty.
	var save_config := load("res://data/save.tres") as SaveConfig
	save_config.path = SCENARIO_SAVE
	DirAccess.remove_absolute(SCENARIO_SAVE)
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
	_world = _main.get("world") as WorldDirector
	_camps = _world.camps
	_god_mode(true)

	_scenario("the game starts in town", _starts_in_town)
	await _scenario_async("camps stream in around the player, asleep", _camps_stream_in)
	await _scenario_async("a new region is announced and its look eases in", _region_change)
	await _scenario_async("the right stick turns the camera and the aim follows", _camera_turns)
	await _scenario_async("a camp wakes when the player comes near", _camp_wakes_on_approach)
	await _scenario_async("lure wakes camps in range and hurries them", _lure_wakes_camps)
	await _scenario_async("clearing a camp drops loot you can pick up", _camp_drops_loot)
	await _scenario_async("with a full backpack, loot stays put until there's room", _full_backpack)
	await _scenario_async("the inventory tab salvages, compares and equips", _inventory_tab)
	await _scenario_async("the character screen pauses and spends points", _character_menu)
	await _scenario_async("player moves with move_right", _player_moves)
	await _scenario_async("debug_spawn adds a batch", _debug_spawn)
	await _scenario_async("swarm keeps out of the player", _swarm_keeps_distance)
	await _scenario_async("nova breaks a nearby pack", _nova_breaks_pack)
	await _scenario_async("a big break freezes, shakes, pops up and flings corpses", _break_feedback)
	await _scenario_async("kills give XP and level-ups refill and grant points", _xp_and_levels)
	await _scenario_async("Stormcaller novas send aftershocks", _stormcaller_aftershocks)
	await _scenario_async("refining raises or lowers an item but never breaks it", _refining)
	await _scenario_async("progress autosaves and loads back", _autosave_and_load)
	await _scenario_async("bolts burst on enemies ahead", _bolts_hit)
	await _scenario_async("touch move stick moves the player", _touch_move)
	await _scenario_async("touch FIRE stick fires and aims", _touch_fire)
	await _scenario_async("touch nova button casts the nova", _touch_nova)
	await _scenario_async("a boss telegraphs its slam; leaving the ring avoids it", _boss_slam)
	await _scenario_async("a slain boss drops rare loot and Geon", _boss_loot)
	await _scenario_async("enemies hurt the player; dodging grants i-frames", _damage_and_dodge)
	await _scenario_async("without mana the nova does not cast", _nova_needs_mana)
	await _scenario_async("a cleared camp comes back after its timer", _camp_respawns)
	await _scenario_async("far camps leave the swarm, near ones come in", _camps_stream_out)
	await _scenario_async("a gate leads into a dungeon and its exit back out", _dungeon_round_trip)
	await _scenario_async("dungeon spawners keep monsters coming", _dungeon_spawners)
	await _scenario_async("dungeon walls stop the player", _dungeon_walls)
	await _scenario_async("the Egg Keeper gives an egg that follows and levels", _keeper_and_pet)
	await _scenario_async("double-clicking an item wears it, again takes it off", _double_click)
	await _scenario_async("a town gate leads into the dungeon and back to town", _town_gate)
	await _scenario_async("dying sends the player back to town", _death_returns_to_town)
	await _scenario_async("New Game erases the save and starts over", _new_game)

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


func _starts_in_town() -> void:
	_check(_world.space == WorldMap.OVERWORLD, "starts in the open world")
	_check(_world.is_town(), "starts in town (%s)" % _world.location_name())
	_check(_player.ground_position().distance_to(_world.map.town_spawn()) < 1.0,
			"standing at the town spawn")
	var overworld := _main.get_node_or_null("World/Overworld") as Node3D
	_check(overworld != null and overworld.visible, "the open world is shown")
	var hall := _main.get_node_or_null("World/Dungeon0") as Node3D
	_check(hall != null and not hall.visible, "dungeons are hidden")
	var awake := 0
	for i in _swarm.state.count:
		awake += _swarm.state.awake[i]
	_check(awake == 0, "%d enemies awake in town" % awake)


func _world_config() -> WorldConfig:
	return _main.get("world_config") as WorldConfig


## The open-world region (other than town) with the lowest level.
func _easy_region() -> int:
	var config := _world_config()
	var best := -1
	for r in config.regions.size():
		if not config.regions[r].is_town \
				and (best < 0 or config.regions[r].level < config.regions[best].level):
			best = r
	return best


func _camps_stream_in() -> void:
	var spot := _world.map.region_center(_easy_region())
	_teleport(spot)
	await _frames(30)
	var sites := _camps.sites
	var config := _world_config()
	var expected := 0
	var spawned := 0
	for s in sites.size():
		var d := sites.centers[s].distance_to(spot)
		if sites.state[s] == CampSites.State.SPAWNED:
			spawned += 1
			expected += sites.alive[s]
			_check(d <= config.despawn_radius, "site %d in the swarm is near (%.0f m)" % [s, d])
		elif sites.state[s] == CampSites.State.DORMANT:
			_check(d > config.spawn_radius, "site %d within reach streamed in (%.0f m)" % [s, d])
	_check(spawned >= 3, "%d camps streamed in" % spawned)
	_check(_swarm.enemy_count() == expected, "%d enemies vs %d camp members" % [
			_swarm.enemy_count(), expected])


func _region_change() -> void:
	var town := _world.map.town_spawn()
	_teleport(town)
	await _frames(3)
	_check(_world.is_town(), "back in town")
	var region := _easy_region()
	var hud := _main.get_node("HudLayer/Hud") as Hud
	_teleport(_world.map.region_center(region))
	await _frames(2)
	_check(_world.region == region, "entered region %d (in %d)" % [region, _world.region])
	_check(hud.banner_showing(), "the region's name is announced")
	var theme := _world_config().regions[region].theme
	_check(_world.atmosphere.target == theme, "the atmosphere heads for the region's look")
	await _frames(roundi(_world_config().atmosphere_blend_time * 60.0) + 30)
	_check(_world.atmosphere.fog_gap() < 0.001, "and settles there (gap %.4f)" %
			_world.atmosphere.fog_gap())


func _camera_turns() -> void:
	var yaw_before := _camera.yaw()
	Input.action_press("aim_right", 1.0)
	await _frames(30)
	Input.action_release("aim_right")
	await _frames(2)
	var turned := angle_difference(yaw_before, _camera.yaw())
	_check(turned < -0.5, "holding right turns the camera right (turned %.2f rad)" % turned)
	var forward := _camera.forward()
	_check(_player.aim_direction.dot(forward) > 0.99, "the aim follows the camera")
	var rig_ground := Vector2(_camera.global_position.x, _camera.global_position.z)
	_check(rig_ground.distance_to(_player.ground_position()) < 1.0, "the camera follows the player")
	_camera.reset_view()


func _go_to_town() -> void:
	_teleport(_world.map.town_spawn())


func _teleport(to: Vector2) -> void:
	_player.position = Vector3(to.x, 0.0, to.y)


func _camp_awake_members(camp: int) -> int:
	var n := 0
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == camp and _swarm.state.awake[i] != 0:
			n += 1
	return n


## A camp in the swarm and still asleep, or -1.
func _sleeping_camp(exclude: int = -1) -> int:
	var sites := _camps.sites
	for s in sites.size():
		if s != exclude and sites.state[s] == CampSites.State.SPAWNED and sites.awake[s] == 0 \
				and sites.is_spawner[s] == 0 and sites.has_boss[s] == 0:
			return s
	return -1


## A spot just outside a camp's aggro range, on the side away from every other camp.
func _beside(camp: int, gap: float) -> Vector2:
	var center := _camps.sites.centers[camp]
	var region_center := _world.map.region_center(_world.map.region_at(center))
	var away := (region_center - center).normalized() if center != region_center else Vector2.RIGHT
	return center + away * (_world_config().aggro_radius + gap)


func _camp_wakes_on_approach() -> void:
	_teleport(_world.map.region_center(_easy_region()))
	await _frames(20)
	var camp := _sleeping_camp()
	_check(camp >= 0, "a sleeping camp nearby")
	if camp < 0:
		return
	var center := _camps.sites.centers[camp]
	_teleport(_beside(camp, 4.0))
	await _frames(5)
	_check(_camps.sites.awake[camp] == 0, "camp stays asleep outside aggro range")
	_teleport(center + (_beside(camp, 4.0) - center).normalized() * (_world_config().aggro_radius - 2.0))
	await _frames(3)
	_check(_camps.sites.awake[camp] == 1, "camp wakes inside aggro range")
	_check(_camp_awake_members(camp) == _camps.sites.alive[camp],
			"all %d members woke (%d)" % [_camps.sites.alive[camp], _camp_awake_members(camp)])
	_go_to_town()


func _lure_wakes_camps() -> void:
	var target := _sleeping_camp()
	_check(target >= 0, "a sleeping camp to lure")
	if target < 0:
		return
	var lure: LureConfig = _player.config.lure
	var center: Vector2 = _camps.sites.centers[target]
	var spot := _beside(target, 6.0)
	_teleport(spot)
	await _frames(2)
	_check(_camps.sites.awake[target] == 0, "camp still asleep before the lure")
	_refill()
	Input.action_press("skill_lure")
	await _frames(1)
	Input.action_release("skill_lure")
	await _frames(1)
	_check(_camps.sites.awake[target] == 1, "lure woke camp %d from %.0f m" % [
			target, spot.distance_to(center)])
	var spent := _player.vitals.max_mana - _player.vitals.mana
	_check(spent > lure.mana_cost * 0.8, "lure cost mana (%.1f)" % spent)
	var boosted := 0
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == target and _swarm.state.boost_until[i] > _swarm.now():
			boosted += 1
	_check(boosted > 0, "lured enemies are sped up")
	_go_to_town()


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
	var numbers := _main.get_node("DamageNumbers") as DamageNumbers
	_check(numbers.active_count() > 0, "damage numbers float over the pack")
	await _frames(120)  # level-up light pillars last 1.5 s
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


func _death_returns_to_town() -> void:
	_teleport(_world.map.region_center(_easy_region()))
	await _frames(5)
	_god_mode(false)
	_player.vitals.health = 1.0
	_place_pack(_player.ground_position(), 1.6, 24)
	await _frames(20)
	_check(_player.vitals.is_dead(), "player died to the pack")
	_check(_popup.is_showing(), "death message shows")
	await _frames(roundi(_player.config.respawn_delay * 60.0) + 10)
	_check(not _player.vitals.is_dead(), "player is back after the respawn delay")
	_check(_world.is_town(), "woke up in town (%s)" % _world.location_name())
	_check(_player.vitals.health == _player.vitals.max_health, "at full health")
	_god_mode(true)


func _camp_respawns() -> void:
	var config := _world_config()
	_teleport(_world.map.region_center(_easy_region()))
	await _frames(20)
	var camp := _sleeping_camp()
	_check(camp >= 0, "a camp to clear")
	if camp >= 0:
		# Each site keeps its own respawn time; shorten this one's.
		var saved_time := _camps.sites.respawn_time[camp]
		_camps.sites.respawn_time[camp] = 0.5
		for i in _swarm.state.count:
			if _swarm.state.camp_ids[i] == camp:
				_swarm.state.health[i] = 0.0
		await _frames(2)
		_check(_camps.sites.state[camp] == CampSites.State.CLEARED, "camp %d cleared" % camp)
		_teleport(_camps.sites.centers[camp] + Vector2(config.respawn_min_distance + 6.0, 0.0))
		await _frames(60)
		_check(_camps.sites.state[camp] == CampSites.State.SPAWNED,
				"camp %d came back (state %d)" % [camp, _camps.sites.state[camp]])
		_camps.sites.respawn_time[camp] = saved_time


func _camps_stream_out() -> void:
	var config := _world_config()
	var near := _world.map.region_center(_easy_region())
	_teleport(near)
	await _frames(20)
	var before := _swarm.enemy_count()
	# Opposite side of the world: the old camps (asleep) leave.
	_teleport(-near)
	await _frames(20)
	var sites := _camps.sites
	for s in sites.size():
		if sites.state[s] == CampSites.State.SPAWNED and sites.awake[s] == 0:
			_check(sites.centers[s].distance_to(-near) <= config.despawn_radius,
					"sleeping site %d out of range left" % s)
	_check(before > 0, "there were camps before (%d)" % before)


func _dungeon_round_trip() -> void:
	var map := _world.map
	_teleport(map.gate_exit_point(0))
	await _frames(5)
	_teleport(map.gate_position(0))
	var config := _world_config()
	await _frames(roundi(config.fade_time * 60.0) * 2 + 20)
	_check(_world.space == 0, "inside dungeon 0 (space %d)" % _world.space)
	_check(not _world.is_travelling() and _world.fade == 0.0, "faded back in")
	_check(_player.ground_position().distance_to(map.arrival_point(0)) < 1.0,
			"standing at the arrival point")
	var hall := _main.get_node("World/Dungeon0") as Node3D
	var overworld := _main.get_node("World/Overworld") as Node3D
	_check(hall.visible and not overworld.visible, "only the dungeon is shown")
	_check(_world.level() == config.dungeons[0].level, "dungeon level applies")
	_check(_swarm.damage_multiplier > 1.0, "dungeon monsters hit harder (%.2f)" %
			_swarm.damage_multiplier)
	_check(_swarm.enemy_count() > 0, "dungeon camps streamed in (%d)" % _swarm.enemy_count())
	_teleport(map.exit_position(0))
	await _frames(roundi(config.fade_time * 60.0) * 2 + 20)
	_check(_world.space == WorldMap.OVERWORLD, "back in the open world")
	_check(_player.ground_position().distance_to(map.gate_exit_point(0)) < 1.0,
			"standing outside the gate")


func _dungeon_spawners() -> void:
	var map := _world.map
	_world.enter(0, map.arrival_point(0))
	await _frames(5)
	var sites := _camps.sites
	var spawner := -1
	for s in sites.size():
		if sites.is_spawner[s] != 0:
			spawner = s
			break
	_check(spawner >= 0, "the dungeon has a spawner")
	if spawner < 0:
		return
	_teleport(sites.centers[spawner] + Vector2(signf(-sites.centers[spawner].x) * 6.0, 0.0))
	await _frames(120)
	var count := _members_of(spawner)
	_check(count >= 4, "the spawner filled up (%d)" % count)
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == spawner:
			_swarm.state.health[i] = 0.0
	await _frames(60)
	_check(_members_of(spawner) >= 1, "and new ones came at once (%d)" % _members_of(spawner))
	_world.return_to_town()
	await _frames(2)


func _dungeon_walls() -> void:
	var map := _world.map
	_world.enter(0, map.arrival_point(0))
	await _frames(3)
	var layout := map.layouts[0]
	var wall_z := layout.rooms[0].position.y + 1.0
	_teleport(Vector2(-2.5, wall_z))
	Input.action_press("move_left")
	await _frames(40)
	Input.action_release("move_left")
	_check(_player.position.x > -4.05, "the hallway wall stopped the player (x %.2f)" %
			_player.position.x)
	_check(not _swarm.is_wall(_player.ground_position()), "never inside a wall")
	_world.return_to_town()
	await _frames(2)


func _keeper_and_pet() -> void:
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	var inventory := _main_var("inventory") as Inventory
	var pets := _main_var("pets") as PetSystem
	var config := _main_var("pet_config") as PetConfig
	inventory.equipped[Inventory.Equip.PET] = null
	_teleport(_world.map.town_spawn() + config.keeper_offset + Vector2(0.0, 1.0))
	await _frames(3)
	_check(menu.is_open() and menu.tab == CharacterMenu.Tab.PET,
			"walking up to the Egg Keeper opens her eggs")
	menu.take_egg(1)
	var pet := inventory.equipped[Inventory.Equip.PET]
	_check(pet != null and pet.pet_type == 1, "her egg is in the pet slot")
	menu.close()
	_go_to_town()
	await _frames(10)
	_check(pets.visible, "the egg follows the player")
	var before := pet.pet_xp + pet.pet_level * 1000.0
	pets.gain_kill_xp(200.0)
	_check(pet.pet_xp + pet.pet_level * 1000.0 > before, "kills give the pet XP")
	pet.pet_level = 10
	PetRules.refresh(config, pet)
	await _frames(3)
	var loot := _main.get_node("Loot") as LootSystem
	_check(loot.collect_radius > 3.0, "a hatched pet collects loot around the player (%.1f m)" %
			loot.collect_radius)


func _double_click() -> void:
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	var inventory := _main_var("inventory") as Inventory
	var boots := ItemData.new()
	boots.slot = AffixDef.Slot.BOOTS
	boots.item_name = "Test Boots"
	inventory.equipped[Inventory.Equip.BOOTS] = null
	inventory.backpack.append(boots)
	menu.open(CharacterMenu.Tab.INVENTORY)
	await _frames(1)
	menu.select_item(boots)
	menu.select_item(boots)
	_check(inventory.equipped[Inventory.Equip.BOOTS] == boots, "double-click wore the boots")
	menu.select_item(boots)
	menu.select_item(boots)
	_check(inventory.equipped[Inventory.Equip.BOOTS] == null and inventory.backpack.has(boots),
			"double-click again took them off")
	inventory.backpack.erase(boots)
	menu.close()
	await _frames(1)


func _town_gate() -> void:
	var map := _world.map
	_go_to_town()
	await _frames(3)
	_teleport(map.town_gate_position(0))
	var config := _world_config()
	await _frames(roundi(config.fade_time * 60.0) * 2 + 20)
	_check(_world.space == 0, "the town gate leads into dungeon 0")
	_teleport(map.exit_position(0))
	await _frames(roundi(config.fade_time * 60.0) * 2 + 20)
	_check(_world.is_town(), "and its exit back to town (%s)" % _world.location_name())


func _members_of(camp: int) -> int:
	var n := 0
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == camp:
			n += 1
	return n


func _main_var(name: String) -> Variant:
	return _main.get(name)


func _camp_drops_loot() -> void:
	var loot := _main.get_node("Loot") as LootSystem
	var inventory := _main_var("inventory") as Inventory
	_teleport(_world.map.region_center(_easy_region()))
	await _frames(20)
	var camp := _sleeping_camp()
	_check(camp >= 0, "a camp to clear")
	if camp < 0:
		return
	var at := Vector2.ZERO
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == camp:
			_swarm.state.health[i] = 0.0
			at = _swarm.state.positions[i]
	var before := loot.ground_count()
	var geon_before := inventory.stones
	await _frames(2)
	_check(_camps.sites.alive[camp] == 0, "camp %d cleared" % camp)
	var dropped := loot.ground_count() - before
	_check(dropped >= 1, "camp dropped %d things" % dropped)
	var piles := loot.ground_geon()
	_check(piles > 0 or dropped == 0, "mostly Geon (%d on the ground)" % piles)
	_teleport(at)
	await _frames(40)
	_check(inventory.stones >= geon_before + piles,
			"walked over it and picked up %d Geon" % (inventory.stones - geon_before))
	_check(loot.ground_count() == before, "nothing left on the ground")
	_go_to_town()


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
	var table := _main_var("attribute_table") as AttributeTable
	var strength: int = table.attributes[0].stats[0]
	var str_before := stats.value(strength)
	progress.attribute_points += 5
	menu.raise_attribute(0, 5)
	_check(progress.attributes[0] >= 5, "five points went into %s" % table.attributes[0].display_name)
	_check(stats.value(strength) > str_before, "and its stat grew")
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



func _bosses() -> BossSystem:
	return _main_var("bosses") as BossSystem


func _camp_has_boss(camp: int) -> bool:
	for i in _swarm.state.count:
		if _swarm.state.camp_ids[i] == camp and _swarm.state.boss_ids[i] >= 0:
			return true
	return false


## Clears the swarm and spawns one lone, awake boss next to the player.
func _lone_boss(offset: Vector2) -> int:
	var bosses := _bosses()
	_swarm.state.clear()
	bosses.reset()
	var boss_type: int = (_main_var("boss_config") as BossConfig).type_index
	var i := _swarm.spawn_at(_player.ground_position() + offset, boss_type)
	return bosses.add(i, 5000.0)


func _on_test_slam(_center: Vector2, inside: bool, damage: float) -> void:
	if inside:
		_slams_inside += 1
	else:
		_slams_outside += 1
	_slam_damage += damage


func _boss_slam() -> void:
	var bosses := _bosses()
	var config := _main_var("boss_config") as BossConfig
	bosses.slammed.connect(_on_test_slam)
	_refill()
	var slot := _lone_boss(Vector2(3.0, 0.0))
	var frames := 0
	while not bosses.is_winding_up(slot) and frames < 300:
		await _frames(1)
		frames += 1
	_check(bosses.is_winding_up(slot), "boss starts a slam when the player is close")
	# Leave the ring before it lands.
	var center: Vector2 = _swarm.state.positions[bosses.index_of(slot)]
	_teleport(center + Vector2(config.slam_radius + 4.0, 0.0))
	await _frames(roundi(config.slam_windup * 60.0) + 5)
	_check(_slams_outside == 1 and _slams_inside == 0, "the slam missed (out %d, in %d)" % [
			_slams_outside, _slams_inside])
	# Next slam: stand in it, vulnerable.
	_god_mode(false)
	_refill()
	frames = 0
	while _slams_inside == 0 and frames < 600:
		var boss_pos: Vector2 = _swarm.state.positions[bosses.index_of(slot)]
		_teleport(boss_pos + Vector2(2.0, 0.0))
		await _frames(1)
		frames += 1
	_check(_slams_inside >= 1, "a second slam came")
	_check(_slam_damage > config.slam_damage * 0.5, "standing in it hurts (%.1f)" % _slam_damage)
	bosses.slammed.disconnect(_on_test_slam)
	_god_mode(true)
	_refill()
	_go_to_town()


func _boss_loot() -> void:
	var bosses := _bosses()
	var loot := _main.get_node("Loot") as LootSystem
	var inventory := _main_var("inventory") as Inventory
	var loot_config := _main_var("loot_config") as LootConfig
	# Items are rare drops now; make this boss's drops all items to check them.
	var item_chance := loot_config.item_drop_chance
	loot_config.item_drop_chance = 1.0
	var slot := _lone_boss(Vector2(12.0, 0.0))
	var stones := inventory.stones
	var on_ground := loot.ground_count()
	_swarm.state.health[bosses.index_of(slot)] = 0.0
	await _frames(3)
	loot_config.item_drop_chance = item_chance
	_check(bosses.alive_count() == 0, "boss is dead")
	_check(loot.ground_geon() > 0, "boss dropped a pile of Geon")
	_check(loot.ground_count() > on_ground + 1, "and items")
	_teleport(_player.ground_position() + Vector2(12.0, 0.0))
	await _frames(40)
	_check(inventory.stones > stones, "picked up the boss's Geon (%d -> %d)" % [stones,
			inventory.stones])
	var rare := false
	for item in inventory.backpack + inventory.equipped:
		if item != null and item.rarity >= 2:
			rare = true
	_check(rare, "a rare item from the boss is in the inventory")
	_go_to_town()


func _stormcaller_aftershocks() -> void:
	var progress := _main_var("progress") as PlayerProgress
	var jobs := _main_var("job_tree") as JobTree
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	progress.level = maxi(progress.level, jobs.unlock_level)
	menu.open()
	await _frames(1)
	menu.choose_job(0)
	menu.close()
	await _frames(1)
	_check(progress.job == 0, "became a Stormcaller")
	await _frames(80)  # nova cooldown
	_refill()
	_place_pack(_player.ground_position(), 9.0, 120)
	Input.action_press("attack_nova")
	await _frames(1)
	Input.action_release("attack_nova")
	var combat := _main_var("combat") as PlayerCombat
	_check(combat.pending_aftershocks() >= 1, "an aftershock is queued")
	await _frames(60)
	_check(combat.pending_aftershocks() == 0, "aftershocks went off")


func _refining() -> void:
	var inventory := _main_var("inventory") as Inventory
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	var item: ItemData = null
	for equipped in inventory.equipped:
		if equipped != null:
			item = equipped
			break
	if item == null:
		# Items are rare drops now: wear one to refine.
		item = ItemGenerator.new(_main_var("loot_config") as LootConfig, 3).roll(1)
		inventory.equipped[inventory.target_for(item)] = item
		inventory.notify_changed()
	inventory.stones = 500
	menu.open()
	var outcomes := {}
	for n in 40:
		outcomes[menu.refine(item)] = true
	menu.close()
	_check(outcomes.has(Refinery.Result.SUCCESS), "some refines succeed")
	_check(inventory.is_equipped(item), "the item is still equipped")
	_check(item.upgrade_level >= 0 and item.upgrade_level <= 10,
			"level %d in range" % item.upgrade_level)
	_check(inventory.stones < 500, "stones were spent")


func _autosave_and_load() -> void:
	var progress := _main_var("progress") as PlayerProgress
	var inventory := _main_var("inventory") as Inventory
	var save := _main_var("save") as SaveManager
	inventory.add_stones(7)
	_check(save.is_dirty(), "a change schedules an autosave")
	await _frames(roundi(1.5 * 60.0) + 10)
	_check(not save.is_dirty(), "autosave written after the delay")
	_check(FileAccess.file_exists(SCENARIO_SAVE), "save file exists")
	# Load the file into fresh objects, as a restart would.
	var jobs := _main_var("job_tree") as JobTree
	var copy := PlayerProgress.new(_main_var("progression_config") as ProgressionConfig,
			_main_var("skill_tree") as SkillTree, _main_var("attribute_table") as AttributeTable)
	var copy_inventory := Inventory.new(inventory.backpack_size)
	var store := SaveStore.new(SCENARIO_SAVE)
	SaveCodec.decode(store.read(), copy, copy_inventory, jobs, 50, 10)
	_check(copy.level == progress.level and copy.job == progress.job,
			"level %d and job %d restored" % [copy.level, copy.job])
	_check(copy_inventory.stones == inventory.stones, "stones restored")
	var equipped := 0
	for item in copy_inventory.equipped:
		if item != null:
			equipped += 1
	var live_equipped := 0
	for item in inventory.equipped:
		if item != null:
			live_equipped += 1
	_check(equipped == live_equipped, "equipped items restored (%d)" % equipped)


func _new_game() -> void:
	var progress := _main_var("progress") as PlayerProgress
	var inventory := _main_var("inventory") as Inventory
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	menu.open()
	menu.press_new_game()
	_check(menu.is_open(), "first press only asks to confirm")
	menu.press_new_game()
	await _frames(2)
	_check(not menu.is_open() and not paused, "confirmed: menu closed, game running")
	_check(progress.level == 1 and progress.job == -1, "back to a level 1 character")
	_check(inventory.stones == 0 and inventory.backpack.is_empty(), "inventory emptied")
	_check(_world.is_town(), "back in town")
	var data := SaveStore.new(SCENARIO_SAVE).read()
	_check(int(data.get("progress", {}).get("level", 0)) == 1, "the save was overwritten")


func _full_backpack() -> void:
	var loot := _main.get_node("Loot") as LootSystem
	var inventory := _main_var("inventory") as Inventory
	var saved_backpack := inventory.backpack.duplicate()
	var saved_equipped := inventory.equipped.duplicate()
	# Weapon slot taken and the backpack full of weapons.
	var filler := ItemData.new()
	filler.slot = AffixDef.Slot.WEAPON
	filler.item_name = "Filler"
	inventory.equipped[AffixDef.Slot.WEAPON] = filler
	while inventory.backpack.size() < inventory.backpack_size:
		inventory.backpack.append(filler)
	loot.clear()
	var item := ItemData.new()
	item.slot = AffixDef.Slot.WEAPON
	item.item_name = "Dropped Wand"
	var spot := _player.ground_position() + Vector2(2.5, 0.0)
	loot.place(item, spot)
	await _frames(60)
	_check(loot.ground_count() == 1, "the item wasn't picked up")
	_check(loot.item_position(0).distance_to(spot) < 0.01,
			"the item stayed where it dropped (moved %.2f m)" % loot.item_position(0).distance_to(spot))
	_teleport(spot)
	await _frames(30)
	_check(loot.ground_count() == 1, "standing on it with no room doesn't pick it up")
	inventory.discard(0)
	await _frames(30)
	_check(loot.ground_count() == 0, "once there's room, it's picked up")
	_check(inventory.backpack.has(item), "it went into the backpack")
	inventory.backpack.assign(saved_backpack)
	inventory.equipped.assign(saved_equipped)
	inventory.notify_changed()
	_teleport(Vector2.ZERO)


func _inventory_tab() -> void:
	var menu := _main.get_node("CharacterMenu") as CharacterMenu
	var inventory := _main_var("inventory") as Inventory
	var loot_config := _main_var("loot_config") as LootConfig
	var saved_backpack := inventory.backpack.duplicate()
	var saved_equipped := inventory.equipped.duplicate()
	inventory.backpack.clear()
	var worn := ItemData.new()
	worn.slot = AffixDef.Slot.AMULET
	worn.rarity = 1
	worn.item_name = "Old Charm"
	worn.stats = PackedInt32Array([PlayerStat.Id.NOVA_RADIUS])
	worn.values = PackedFloat32Array([0.05])
	inventory.equipped[AffixDef.Slot.AMULET] = worn
	var better := ItemData.new()
	better.slot = AffixDef.Slot.AMULET
	better.rarity = 2
	better.item_name = "Bright Charm"
	better.stats = PackedInt32Array([PlayerStat.Id.NOVA_RADIUS])
	better.values = PackedFloat32Array([0.09])
	inventory.backpack.append(better)
	for n in 3:
		var junk := ItemData.new()
		junk.slot = AffixDef.Slot.WEAPON
		junk.item_name = "Junk"
		inventory.backpack.append(junk)
	# I (or Y) opens straight to the inventory.
	var press := InputEventAction.new()
	press.action = "menu_inventory"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	_check(menu.is_open() and menu.tab == CharacterMenu.Tab.INVENTORY, "opened on the inventory tab")
	var stones := inventory.stones
	var gained := menu.salvage_all(0)
	_check(gained == loot_config.salvage_stones[0] * 3, "salvaged the 3 commons (%d)" % gained)
	_check(inventory.stones == stones + gained and inventory.backpack.size() == 1,
			"only the rare charm is left")
	_check(menu.salvage_all(1) == 0, "salvage-all magic asks to confirm first")
	menu.select_item(better)
	_check(menu.selected_item() == better, "selected the charm")
	var rows := ItemCompare.compare(better, worn)
	_check(rows[0]["change"] == ItemCompare.Change.BETTER, "it compares as better")
	menu.equip_item(better)
	_check(inventory.equipped[AffixDef.Slot.AMULET] == better, "equipped")
	_check(inventory.backpack.has(worn), "old charm went to the backpack")
	var anchor := menu.get_child(0) as Control
	menu.show_tooltip(worn, anchor)
	_check(menu.tooltip_showing(), "hovering an item shows its tooltip")
	menu.hide_tooltip(anchor)
	_check(not menu.tooltip_showing(), "and leaving hides it")
	var rare := ItemData.new()
	rare.slot = AffixDef.Slot.RING
	rare.rarity = 2
	rare.item_name = "Spare Ring"
	inventory.backpack.append(rare)
	_check(menu.salvage_all(-1) == 0, "salvage everything asks to confirm first")
	var everything := menu.salvage_all(-1)
	_check(everything > 0 and inventory.backpack.is_empty(),
			"salvage everything took the rare too (%d stones)" % everything)
	_check(inventory.equipped[AffixDef.Slot.AMULET] == better, "but not what's worn")
	menu.show_tab(CharacterMenu.Tab.CHARACTER)
	_check(menu.tab == CharacterMenu.Tab.CHARACTER, "switched tabs")
	menu.close()
	await _frames(1)
	inventory.backpack.assign(saved_backpack)
	inventory.equipped.assign(saved_equipped)
	inventory.notify_changed()
