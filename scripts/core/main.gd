extends Node3D
## Wires the game together and runs the frame. Order each frame:
##   player -> swarm.simulate -> player attacks -> bolts -> swarm.resolve_deaths
##   -> zone (camp wake-ups, deaths) -> player damage -> swarm.draw -> effects
##   -> corpses -> popup -> hud -> camera
## Damage has to land between simulate() and resolve_deaths(), while enemy
## indices still match the spatial hash. During hit-stop only the camera
## (shake), popup and HUD advance.
##
## Zone flow: a zone starts with all camps asleep. Clearing every camp moves
## on to the next level after a short pause; dying restarts the current one.
## Character progress (level, skills, items) carries across both. Clearing a
## camp drops loot; kills give XP. Progress autosaves (SaveManager) and the
## game resumes at the saved zone.

const ZONE_MESSAGE_TIME := 2.0
const START_POSITION := Vector3.ZERO

@export var feedback_config: FeedbackConfig
@export var audio_config: AudioConfig
@export var zone_config: ZoneConfig
@export var progression_config: ProgressionConfig
@export var skill_tree: SkillTree
@export var loot_config: LootConfig
@export var job_tree: JobTree
@export var boss_config: BossConfig
@export var save_config: SaveConfig

var combat: PlayerCombat
var zone: ZoneDirector
var progress: PlayerProgress
var inventory: Inventory
var stats: PlayerStats
var bosses: BossSystem
var refinery: Refinery
var save: SaveManager

var _loot_rng := RandomNumberGenerator.new()

## Seconds until the pending zone (re)start, or < 0 when none is pending.
var _restart_in := -1.0
var _restart_level := 1

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _swarm: SwarmManager = $Swarm
@onready var _projectiles: ProjectileSystem = $Projectiles
@onready var _effects: EffectSystem = $Effects
@onready var _corpses: CorpseSystem = $Corpses
@onready var _sfx: SfxPlayer = $Sfx
@onready var _popup: BreakPopup = $BreakPopup
@onready var _feedback: CombatFeedback = $Feedback
@onready var _hud: Hud = $HudLayer/Hud
@onready var _loot: LootSystem = $Loot
@onready var _menu: CharacterMenu = $CharacterMenu
@onready var _touch: TouchControls = $TouchLayer/TouchControls
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	var half_extent := _arena.config.half_extent
	progress = PlayerProgress.new(progression_config, skill_tree)
	inventory = Inventory.new(loot_config.backpack_size)
	stats = PlayerStats.new(progress, skill_tree, inventory, progression_config, job_tree)
	inventory.changed.connect(stats.recompute)
	progress.leveled_up.connect(_on_leveled_up)
	_player.setup(_camera_rig, half_extent)
	_player.set_stats(stats)
	_camera_rig.follow(_player)
	_corpses.setup(_swarm.config.enemy_types, feedback_config)
	_swarm.setup(half_extent, _effects, _corpses, zone_config.max_camps, boss_config.max_per_zone)
	_projectiles.setup(_player.config.bolt, _effects, half_extent)
	bosses = BossSystem.new(boss_config, _swarm, _effects)
	bosses.slammed.connect(_on_boss_slammed)
	bosses.boss_killed.connect(_on_boss_killed)
	zone = ZoneDirector.new(zone_config, _swarm, half_extent, bosses, boss_config)
	combat = PlayerCombat.new(_player, _swarm, _projectiles, _effects, zone, stats)
	zone.camp_cleared.connect(_on_camp_cleared)
	_loot_rng.randomize()
	_loot.setup(loot_config, inventory, ItemGenerator.new(loot_config))
	_loot.picked_up.connect(_on_item_picked_up)
	_loot.backpack_full.connect(_on_backpack_full)
	refinery = Refinery.new(loot_config)
	_menu.setup(progress, skill_tree, inventory, stats, loot_config, job_tree, refinery)
	_menu.job_chosen.connect(_on_job_chosen)
	_menu.refined.connect(_on_refined)
	_menu.opened.connect(_touch.release_all)
	_sfx.setup(audio_config)
	_popup.setup(feedback_config)
	_feedback.setup(feedback_config, audio_config, _camera_rig, _popup, _sfx, _swarm, combat,
			_projectiles, _player)
	_hud.setup(_player.vitals, zone, _player, half_extent, progress)
	_hud.setup_bosses_and_jobs(bosses, boss_config.display_name, job_tree)
	_overlay.swarm = _swarm
	_overlay.combat = combat
	save = SaveManager.new(save_config, progress, inventory, job_tree,
			progression_config.max_level, loot_config.upgrade_max)
	var level := save.load_game()
	stats.recompute()
	_connect_autosave()
	start_zone(level)
	_greet()


## Every change worth keeping schedules an autosave.
func _connect_autosave() -> void:
	progress.leveled_up.connect(save.mark_dirty.unbind(1))
	progress.job_changed.connect(save.mark_dirty.unbind(2))
	progress.skills_changed.connect(save.mark_dirty)
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


## Erases the save and starts a brand-new character at zone 1.
func new_game() -> void:
	save.erase()
	progress.reset()
	inventory.reset()
	stats.recompute()
	start_zone(1)
	save.save_now()
	_hud.toast("New game started", Color(0.75, 0.9, 1.0))


func _notification(what: int) -> void:
	# Closing the window, switching tabs or backgrounding a phone: save now.
	if save == null:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		save.save_now()


## Resets the player and spawns the given level's camps.
func start_zone(level: int) -> void:
	_restart_in = -1.0
	zone.generate(level, Vector2(START_POSITION.x, START_POSITION.z))
	_loot.clear()
	_player.reset_to(START_POSITION)
	_player.vitals.reset()
	_camera_rig.follow(_player)
	if save != null:
		save.set_zone_level(level)
	_popup.show_message("ZONE %d" % level, Color(0.85, 0.9, 1.0), ZONE_MESSAGE_TIME)


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
	zone.record_deaths(_swarm.resolve_deaths())
	progress.add_xp(_swarm.last_xp)
	zone.tick(player_pos)
	if alive:
		bosses.tick(dt, player_pos, _player.vitals)
	_loot.tick(dt, player_pos)
	_update_player_health(dt, now, alive)
	_update_zone_flow(dt)
	_swarm.draw()
	_effects.tick(dt)
	_corpses.tick(dt)
	_popup.tick(dt)
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
	if _restart_in >= 0.0:
		return
	_popup.show_message("YOU DIED", Color(1.0, 0.3, 0.25), _player.config.respawn_delay)
	_restart_in = _player.config.respawn_delay
	_restart_level = zone.level


func _update_zone_flow(dt: float) -> void:
	if _restart_in < 0.0 and zone.is_cleared() and not _player.vitals.is_dead():
		_popup.show_message("ZONE CLEARED", Color(1.0, 0.85, 0.35), ZONE_MESSAGE_TIME)
		_restart_in = ZONE_MESSAGE_TIME
		_restart_level = zone.level + 1
	if _restart_in >= 0.0:
		_restart_in -= dt
		if _restart_in < 0.0:
			start_zone(_restart_level)


func _on_camp_cleared(_camp: int, at: Vector2, last_camp: bool) -> void:
	var amount := _loot_rng.randi_range(loot_config.camp_drop_min, loot_config.camp_drop_max)
	if last_camp:
		amount += loot_config.zone_clear_bonus_drops
	_loot.drop(at, amount, zone.level)
	var stones := _loot_rng.randi_range(loot_config.camp_stones_min, loot_config.camp_stones_max)
	inventory.add_stones(stones)
	_hud.toast("+%d Refining Stones" % stones, Color(0.75, 0.85, 1.0))


func _on_boss_killed(_slot: int, at: Vector2) -> void:
	_loot.drop(at, boss_config.extra_drops, zone.level, boss_config.min_drop_rarity)
	inventory.add_stones(boss_config.stones)
	_hud.banner("%s SLAIN" % boss_config.display_name.to_upper(), Color(1.0, 0.7, 0.3), 2.0)
	_hud.toast("+%d Refining Stones" % boss_config.stones, Color(0.75, 0.85, 1.0))


func _on_boss_slammed(_center: Vector2, _inside: bool, damage: float) -> void:
	_feedback.boss_slam(damage > 0.0)
	if damage > 0.0:
		_hud.flash_hurt(damage)
		if _player.vitals.is_dead():
			_on_player_died()


func _on_job_chosen(job: int) -> void:
	_hud.banner(job_tree.jobs[job].display_name.to_upper(), job_tree.jobs[job].color, 2.0)
	_feedback.level_up()


func _on_refined(result: Refinery.Result, _item: ItemData) -> void:
	if result == Refinery.Result.SUCCESS:
		_feedback.refined(true)
	elif result == Refinery.Result.DOWNGRADED or result == Refinery.Result.FAILED:
		_feedback.refined(false)


func _on_item_picked_up(item: ItemData) -> void:
	var equipped := inventory.equipped[item.slot] == item
	_hud.toast("%s %s" % ["Equipped" if equipped else "Picked up", item.item_name],
			loot_config.rarity_colors[item.rarity])
	_feedback.item_picked_up()


func _on_backpack_full() -> void:
	_hud.toast("Backpack full - open CHAR to discard", Color(1.0, 0.5, 0.4))


func _on_leveled_up(level: int) -> void:
	if progress.promote_if_ready(job_tree):
		_hud.toast("Promoted to %s!" % progress.job_title(job_tree), job_tree.jobs[progress.job].color)
	stats.recompute()
	_player.vitals.health = _player.vitals.max_health
	_player.vitals.mana = _player.vitals.max_mana
	_hud.banner("LEVEL %d" % level, progression_config.level_up_color, 1.8)
	_feedback.level_up()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_swarm.spawn_around(_player.ground_position(), _swarm.config.debug_spawn_batch)
