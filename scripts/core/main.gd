extends Node3D
## Wires the game together and runs the frame. Order each frame:
##   player -> swarm.simulate -> player attacks -> bolts -> swarm.resolve_deaths
##   -> camps (deaths, wake-ups, streaming) -> bosses -> loot -> player damage
##   -> world (regions, gates) -> swarm.draw -> effects -> damage numbers
##   -> corpses -> popup -> hud -> camera
## Damage has to land between simulate() and resolve_deaths(), while enemy
## indices still match the spatial hash. During hit-stop only the camera
## (shake), popup and HUD advance.
##
## The world (WorldDirector) is an open map of regions around a town, with
## dungeons behind gates. Camps stream in near the player and come back a
## minute after clearing; dungeon spawners refill at once. Clearing a camp
## drops loot by its level (better in dungeons); kills give XP scaled by the
## level where the player is. Dying sends the player back to town. Progress
## autosaves (SaveManager); the game always resumes in town.

const LOCATION_MESSAGE_TIME := 2.0

@export var feedback_config: FeedbackConfig
@export var audio_config: AudioConfig
@export var world_config: WorldConfig
@export var progression_config: ProgressionConfig
@export var skill_tree: SkillTree
@export var attribute_table: AttributeTable
@export var loot_config: LootConfig
@export var job_tree: JobTree
@export var boss_config: BossConfig
@export var save_config: SaveConfig
@export var damage_numbers_config: DamageNumbersConfig

var combat: PlayerCombat
var world: WorldDirector
var camps: CampDirector
var progress: PlayerProgress
var inventory: Inventory
var stats: PlayerStats
var bosses: BossSystem
var refinery: Refinery
var save: SaveManager

var _loot_rng := RandomNumberGenerator.new()
var _pillar_effect := -1

## Seconds until the player respawns in town, or < 0 when not dead.
var _respawn_in := -1.0

@onready var _scenery: Node3D = $World
@onready var _player: Player = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _swarm: SwarmManager = $Swarm
@onready var _projectiles: ProjectileSystem = $Projectiles
@onready var _effects: EffectSystem = $Effects
@onready var _numbers: DamageNumbers = $DamageNumbers
@onready var _corpses: CorpseSystem = $Corpses
@onready var _sfx: SfxPlayer = $Sfx
@onready var _popup: BreakPopup = $BreakPopup
@onready var _feedback: CombatFeedback = $Feedback
@onready var _hud: Hud = $HudLayer/Hud
@onready var _loot: LootSystem = $Loot
@onready var _menu: CharacterMenu = $CharacterMenu
@onready var _touch: TouchControls = $TouchLayer/TouchControls
@onready var _overlay: DebugOverlay = $DebugOverlay
@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	var flow_half := _swarm.config.flow_half_extent
	progress = PlayerProgress.new(progression_config, skill_tree, attribute_table)
	inventory = Inventory.new(loot_config.backpack_size)
	stats = PlayerStats.new(progress, skill_tree, inventory, progression_config, job_tree)
	inventory.changed.connect(stats.recompute)
	progress.leveled_up.connect(_on_leveled_up)
	progress.attributes_changed.connect(stats.recompute)
	_player.setup(_camera_rig, flow_half)
	_player.set_stats(stats)
	_corpses.setup(_swarm.config.enemy_types, feedback_config)
	_swarm.setup(flow_half, _effects, _corpses, _max_sites(), boss_config.max_active)
	_projectiles.setup(_player.config.bolt, _effects, flow_half)
	_numbers.setup(damage_numbers_config, _swarm)
	_player.vitals.evaded.connect(func() -> void: _numbers.show_evade(_player.ground_position()))
	_pillar_effect = _effects.register(feedback_config.pillar_effect)
	bosses = BossSystem.new(boss_config, _swarm, _effects)
	bosses.slammed.connect(_on_boss_slammed)
	bosses.boss_killed.connect(_on_boss_killed)
	world = WorldDirector.new(world_config, _swarm, bosses, boss_config, _scenery,
			_environment.environment, _sun)
	camps = world.camps
	combat = PlayerCombat.new(_player, _swarm, _projectiles, _effects, camps, stats)
	camps.camp_cleared.connect(_on_camp_cleared)
	camps.spawner_kill.connect(_on_spawner_kill)
	world.location_entered.connect(_on_location_entered)
	_loot_rng.randomize()
	_loot.setup(loot_config, inventory, ItemGenerator.new(loot_config))
	world.setup_actors(_player, _camera_rig, _projectiles, _loot)
	_loot.picked_up.connect(_on_item_picked_up)
	_loot.picked_up_geon.connect(_on_geon_picked_up)
	_loot.backpack_full.connect(_on_backpack_full)
	refinery = Refinery.new(loot_config)
	_menu.setup(progress, skill_tree, inventory, stats, loot_config, job_tree, refinery)
	_menu.job_chosen.connect(_on_job_chosen)
	_menu.refined.connect(_on_refined)
	_menu.opened.connect(_touch.release_all)
	_menu.opened.connect(_camera_rig.release_mouse)
	_sfx.setup(audio_config)
	_popup.setup(feedback_config)
	_feedback.setup(feedback_config, audio_config, _camera_rig, _popup, _sfx, _swarm, combat,
			_projectiles, _player)
	_hud.setup(_player.vitals, world, _player, progress)
	_hud.setup_bosses_and_jobs(bosses, boss_config.display_name, job_tree)
	_hud.setup_camera_and_skills(_camera_rig, combat)
	_overlay.swarm = _swarm
	_overlay.combat = combat
	save = SaveManager.new(save_config, progress, inventory, job_tree,
			progression_config.max_level, loot_config.upgrade_max)
	_check_data()
	save.load_game()
	stats.recompute()
	_connect_autosave()
	world.return_to_town()
	_jump_from_url()
	_greet()


## Stat lists inside nested data (attributes, job perks) must pair a value
## with each stat. An export that loses those lists (binary-converted
## resources in Godot 4.3 did) shows up here as an error, which the web
## smoke test catches.
func _check_data() -> void:
	for def in attribute_table.attributes:
		if def.per_point.size() != def.stats.size():
			push_error("Attribute %s has %d values for %d stats" % [def.display_name,
					def.per_point.size(), def.stats.size()])
	for job in job_tree.jobs:
		for perks: JobPerks in [job.rank1, job.rank2]:
			if perks != null and perks.values.size() != perks.stats.size():
				push_error("Job %s perks have %d values for %d stats" % [job.display_name,
						perks.values.size(), perks.stats.size()])


## Every space's camps share the swarm's camp ids, so size them for the biggest.
func _max_sites() -> int:
	var most := 1
	# Upper bound: every region's camps, or a dungeon's camps, spawners and boss.
	for region in world_config.regions:
		most += region.camp_count
	for dungeon in world_config.dungeons:
		most = maxi(most, dungeon.camp_count + dungeon.spawner_count + 1)
	return most


## Web only, for previewing: index.html?region=N starts in region N (0 is the
## north-west corner, row by row), ?dungeon=N inside dungeon N (from 1).
func _jump_from_url() -> void:
	if not OS.has_feature("web"):
		return
	var query := str(JavaScriptBridge.eval("window.location.search", true))
	var region := RegEx.create_from_string("region=(\\d+)").search(query)
	if region != null:
		var r := clampi(int(region.get_string(1)), 0, world_config.regions.size() - 1)
		world.enter(WorldMap.OVERWORLD, world.map.region_center(r) + Vector2(0.0, 20.0))
	var dungeon := RegEx.create_from_string("dungeon=(\\d+)").search(query)
	if dungeon != null:
		var d := clampi(int(dungeon.get_string(1)) - 1, 0, world_config.dungeons.size() - 1)
		world.enter(d, world.map.arrival_point(d))


## Every change worth keeping schedules an autosave.
func _connect_autosave() -> void:
	progress.leveled_up.connect(save.mark_dirty.unbind(1))
	progress.job_changed.connect(save.mark_dirty.unbind(2))
	progress.skills_changed.connect(save.mark_dirty)
	progress.attributes_changed.connect(save.mark_dirty)
	inventory.changed.connect(save.mark_dirty)
	_menu.opened.connect(save.save_now)
	_menu.closed.connect(save.save_now)
	_menu.new_game_requested.connect(new_game)


func _greet() -> void:
	match save.status():
		SaveStore.Status.OK:
			var title := progress.job_title(job_tree)
			_hud.toast("Welcome back - level %d%s" % [progress.level,
					" " + title if title != "" else ""], Color(0.75, 0.9, 1.0))
		SaveStore.Status.CORRUPT:
			_hud.toast("Your save couldn't be read; starting fresh (kept a backup)",
					Color(1.0, 0.6, 0.4))


## Erases the save and starts a brand-new character in town.
func new_game() -> void:
	save.erase()
	progress.reset()
	inventory.reset()
	stats.recompute()
	_respawn()
	save.save_now()
	_hud.toast("New game started", Color(0.75, 0.9, 1.0))


func _notification(what: int) -> void:
	# Closing the window, switching tabs or backgrounding a phone: save now.
	if save == null:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		save.save_now()


## Back to town at full health.
func _respawn() -> void:
	_respawn_in = -1.0
	world.return_to_town()
	_player.vitals.reset()


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	var dt := minf(delta, _swarm.config.max_tick_delta)
	if _feedback.consume_hitstop(dt):
		_popup.tick(dt)
		_hud.tick(dt)
		_camera_rig.tick(dt)
		return
	var alive := not _player.vitals.is_dead()
	var now := _swarm.now()
	if alive:
		_player.tick(dt, now)
	var player_pos := _player.ground_position()
	_swarm.simulate(dt, player_pos, _player.config.radius, _player.config.lure.speed_multiplier)
	if alive:
		combat.tick(dt)
	_projectiles.tick(dt, _swarm)
	camps.record_deaths(_swarm.resolve_deaths())
	progress.add_xp(_swarm.last_xp * world.xp_multiplier())
	camps.tick(player_pos)
	if alive:
		bosses.tick(dt, player_pos, _player.vitals)
	_loot.tick(dt, player_pos)
	_swarm.damage_multiplier = world.damage_multiplier()
	_update_player_health(dt, now, alive)
	_update_respawn(dt)
	if alive:
		world.tick(dt, _player.ground_position())
	_swarm.draw()
	_effects.tick(dt)
	_numbers.tick(dt)
	_corpses.tick(dt)
	_popup.tick(dt)
	_hud.show_skills = not _touch.visible
	_hud.tick(dt)
	_camera_rig.tick(dt)
	save.tick(dt)
	_overlay.sim_usec = Time.get_ticks_usec() - start


func _update_player_health(dt: float, now: float, alive: bool) -> void:
	if not alive:
		return
	var vitals := _player.vitals
	vitals.tick(dt)
	var taken := vitals.take_damage(_swarm.contact_dps() * dt, now)
	if taken > 0.0:
		_hud.flash_hurt(taken)
		_feedback.player_hurt(taken, dt)
	if vitals.is_dead():
		_on_player_died()


func _on_player_died() -> void:
	if _respawn_in >= 0.0:
		return
	_popup.show_message("YOU DIED", Color(1.0, 0.3, 0.25), _player.config.respawn_delay)
	_respawn_in = _player.config.respawn_delay


func _update_respawn(dt: float) -> void:
	if _respawn_in < 0.0:
		return
	_respawn_in -= dt
	if _respawn_in < 0.0:
		_respawn()
		_hud.toast("You wake up in %s" % world.location_name(), Color(0.75, 0.9, 1.0))


## Loot by the camp's level; dungeons add drops, rarity and Geon.
## Drops by the camp's level: mostly Geon, now and then an item. Dungeons add
## drops, a minimum item rarity and bigger piles.
func _on_camp_cleared(_camp: int, at: Vector2, level: int, _had_boss: bool) -> void:
	var amount := _loot_rng.randi_range(loot_config.camp_drop_min, loot_config.camp_drop_max)
	var min_rarity := 0
	var multiplier := 1.0
	var dungeon := world.dungeon()
	if dungeon != null:
		amount += dungeon.extra_drops
		min_rarity = dungeon.min_drop_rarity
		multiplier = dungeon.geon_multiplier
	_loot.drop_rewards(at, amount, level, min_rarity, multiplier)


## Spawner monsters drop rarely, one at a time: farming adds up.
func _on_spawner_kill(_camp: int, at: Vector2, level: int) -> void:
	var dungeon := world.dungeon()
	if dungeon == null:
		return
	if _loot_rng.randf() < dungeon.spawner_drop_chance:
		_loot.drop_rewards(at, 1, level, dungeon.min_drop_rarity, dungeon.geon_multiplier)
	if _loot_rng.randf() < dungeon.spawner_geon_chance:
		_loot.place_geon(1, at)


func _on_location_entered(title: String, level: int, is_town: bool) -> void:
	var detail := "Safe haven" if is_town else "Level %d" % level
	_hud.banner("%s  -  %s" % [title.to_upper(), detail], Color(1.0, 0.85, 0.55),
			LOCATION_MESSAGE_TIME)


func _on_boss_killed(_slot: int, at: Vector2) -> void:
	_effects.spawn(_pillar_effect, Vector3(at.x, 0.0, at.y), 2.0)
	var level := world.level()
	_loot.drop_rewards(at, boss_config.extra_drops, level, boss_config.min_drop_rarity)
	var growth := 1.0 + loot_config.geon_growth_per_level * (level - 1)
	_loot.place_geon(roundi(boss_config.geon * growth), at)
	_hud.banner("%s SLAIN" % boss_config.display_name.to_upper(), Color(1.0, 0.7, 0.3), 2.0)


func _on_boss_slammed(_center: Vector2, _inside: bool, damage: float) -> void:
	_feedback.boss_slam(damage > 0.0)
	if damage > 0.0:
		_hud.flash_hurt(damage)
		if _player.vitals.is_dead():
			_on_player_died()


func _on_job_chosen(job: int) -> void:
	_hud.banner(job_tree.jobs[job].display_name.to_upper(), job_tree.jobs[job].color, 2.0)
	_effects.spawn(_pillar_effect, _player.position, 1.0)
	_feedback.level_up()


func _on_refined(result: Refinery.Result, _item: ItemData) -> void:
	if result == Refinery.Result.SUCCESS:
		_feedback.refined(true)
	elif result == Refinery.Result.DOWNGRADED or result == Refinery.Result.FAILED:
		_feedback.refined(false)


func _on_geon_picked_up(amount: int) -> void:
	_hud.toast("+%d %s" % [amount, loot_config.currency_name], loot_config.geon_color)


func _on_item_picked_up(item: ItemData) -> void:
	var equipped := inventory.is_equipped(item)
	_hud.toast("%s %s" % ["Equipped" if equipped else "Picked up", item.item_name],
			loot_config.rarity_colors[item.rarity])
	_feedback.item_picked_up()


func _on_backpack_full() -> void:
	_hud.toast("Backpack full - open BAG (I) to salvage", Color(1.0, 0.5, 0.4))


func _on_leveled_up(level: int) -> void:
	if progress.promote_if_ready(job_tree):
		_hud.toast("Promoted to %s!" % progress.job_title(job_tree), job_tree.jobs[progress.job].color)
	stats.recompute()
	_player.vitals.health = _player.vitals.max_health
	_player.vitals.mana = _player.vitals.max_mana
	_hud.banner("LEVEL %d" % level, progression_config.level_up_color, 1.8)
	_effects.spawn(_pillar_effect, _player.position, 1.0)
	_feedback.level_up()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_swarm.spawn_around(_player.ground_position(), _swarm.config.debug_spawn_batch)
