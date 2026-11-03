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
@export var pet_config: PetConfig
@export var quest_list: QuestList
@export var set_list: SetList
@export var active_list: ActiveSkillList
@export var summon_config: SummonConfig

var combat: PlayerCombat
var actives: ActiveSkills
var summons: SummonSystem
var world: WorldDirector
var camps: CampDirector
var progress: PlayerProgress
var inventory: Inventory
var stats: PlayerStats
var bosses: BossSystem
var refinery: Refinery
var save: SaveManager
var quests: QuestLog
var pets: PetSystem

var _loot_rng := RandomNumberGenerator.new()
var _gamepads := GamepadCompat.new()
var _pillar_effect := -1

## Seconds until the player respawns in town, or < 0 when not dead.
var _respawn_in := -1.0
## True from walking up to the Egg Keeper until walking away again.
var _keeper_engaged := false

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
	progress.set_actives(active_list)
	inventory = Inventory.new(loot_config.backpack_size)
	inventory.sets = set_list
	stats = PlayerStats.new(progress, skill_tree, inventory, progression_config, job_tree)
	inventory.changed.connect(stats.recompute)
	inventory.changed.connect(_dress_hero)
	progress.leveled_up.connect(_on_leveled_up)
	progress.attributes_changed.connect(stats.recompute)
	_player.setup(_camera_rig, flow_half)
	_player.set_stats(stats)
	_player.wall_check = _swarm.is_wall
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
	actives = ActiveSkills.new(active_list, _player, _swarm, _effects, progress, stats)
	camps.camp_cleared.connect(_on_camp_cleared)
	camps.spawner_kill.connect(_on_spawner_kill)
	world.location_entered.connect(_on_location_entered)
	quests = QuestLog.new(quest_list)
	quests.completed.connect(_on_quest_completed)
	pets = PetSystem.new()
	pets.name = "Pet"
	add_child(pets)
	pets.setup(pet_config, inventory, _loot, _player)
	pets.evolved.connect(_on_pet_evolved)
	world.space_entered.connect(pets.snap_to_player.unbind(1))
	world.space_entered.connect(actives.clear.unbind(1))
	summons = SummonSystem.new(summon_config, _swarm, bosses, boss_config, inventory, world,
			_player, progress)
	world.space_entered.connect(summons.reset.unbind(1))
	summons.summoned.connect(_on_boss_summoned)
	_loot_rng.randomize()
	_loot.setup(loot_config, inventory, ItemGenerator.new(loot_config))
	world.setup_actors(_player, _camera_rig, _projectiles, _loot)
	_loot.picked_up.connect(_on_item_picked_up)
	_loot.picked_up_geon.connect(_on_geon_picked_up)
	_loot.picked_up_blessed.connect(_on_blessed_picked_up)
	_loot.backpack_full.connect(_on_backpack_full)
	refinery = Refinery.new(loot_config)
	_menu.setup(progress, skill_tree, inventory, stats, loot_config, job_tree, refinery)
	_menu.job_chosen.connect(_on_job_chosen)
	_menu.setup_pets(pet_config, quests)
	_menu.egg_taken.connect(_on_egg_taken)
	_menu.refined.connect(_on_refined)
	_menu.setup_summons(summon_config)
	_menu.summon_requested.connect(func() -> void: summon_boss())
	var talisman_rules := TalismanRules.new(loot_config)
	_menu.setup_talismans(talisman_rules)
	_loot.talismans = talisman_rules
	_loot.picked_up_talisman.connect(_on_talisman_picked_up)
	_loot.picked_up_shard.connect(_on_shard_picked_up)
	_loot.shard_color = summon_config.shard_color
	_menu.talisman_applied.connect(_on_talisman_applied)
	_menu.opened.connect(_touch.release_all)
	_menu.opened.connect(_camera_rig.release_mouse)
	_sfx.setup(audio_config)
	_popup.setup(feedback_config)
	_feedback.setup(feedback_config, audio_config, _camera_rig, _popup, _sfx, _swarm, combat,
			_projectiles, _player)
	_hud.setup(_player.vitals, world, _player, progress)
	_hud.setup_bosses_and_jobs(bosses, boss_config.display_name, job_tree)
	_hud.setup_camera_and_skills(_camera_rig, combat)
	_hud.setup_actives(actives, progress)
	actives.cast.connect(func(_skill: int, _center: Vector2) -> void: _feedback.skill_cast())
	actives.impact.connect(func(_skill: int, _center: Vector2, big: bool) -> void:
			_feedback.skill_impact(big))
	actives.locked.connect(_on_skill_locked)
	_hud.setup_quests(quests)
	_overlay.swarm = _swarm
	_overlay.combat = combat
	save = SaveManager.new(save_config, progress, inventory, job_tree,
			progression_config.max_level, loot_config.upgrade_max)
	_check_data()
	save.set_quests(quests)
	quests.changed.connect(save.mark_dirty)
	save.load_game()
	_build_keeper()
	stats.recompute()
	_dress_hero()
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
	if set_list != null:
		for def in set_list.sets:
			if def.bonus_values.size() != def.bonus_stats.size() \
					or def.bonus_pieces.size() != def.bonus_stats.size():
				push_error("Set %s has mismatched bonus lists" % def.set_name)
			for piece in def.pieces:
				if piece.values.size() != piece.stats.size():
					push_error("Set piece %s has %d values for %d stats" % [piece.piece_name,
							piece.values.size(), piece.stats.size()])


## Every space's camps share the swarm's camp ids, so size them for the biggest.
func _max_sites() -> int:
	var most := 1
	# Upper bound: every region's camps, or every camp of a dungeon.
	for region in world_config.regions:
		most += region.camp_count
	for dungeon in world_config.dungeons:
		most = maxi(most, dungeon.arena_camps + 1 + dungeon.boss_room_camps
				+ dungeon.boss_room_spawners)
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
	quests.reset()
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
	_gamepads.tick()
	var alive := not _player.vitals.is_dead()
	var now := _swarm.now()
	if alive:
		_player.tick(dt, now)
	var player_pos := _player.ground_position()
	_swarm.simulate(dt, player_pos, _player.config.radius, _player.config.lure.speed_multiplier)
	if alive:
		combat.tick(dt)
		actives.tick(dt)
	_projectiles.tick(dt, _swarm)
	var dead := _swarm.resolve_deaths()
	camps.record_deaths(dead)
	_roll_blessed_stones(dead)
	_roll_summon_shards(dead)
	var xp := _swarm.last_xp * world.xp_multiplier()
	progress.add_xp(xp)
	pets.gain_kill_xp(xp)
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
	pets.tick(dt)
	_check_keeper()
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
## drops, a minimum item rarity and bigger piles, more so in deeper rooms.
func _on_camp_cleared(camp: int, at: Vector2, level: int, _had_boss: bool) -> void:
	quests.on_camp_cleared()
	var amount := _loot_rng.randi_range(loot_config.camp_drop_min, loot_config.camp_drop_max)
	var min_rarity := 0
	var multiplier := 1.0
	var dungeon := world.dungeon()
	if dungeon != null:
		amount += dungeon.extra_drops
		min_rarity = _dungeon_rarity(dungeon, camp)
		multiplier = _dungeon_geon(dungeon, camp)
	_loot.drop_rewards(at, amount, level, min_rarity, multiplier)


## A dungeon room's minimum item rarity: one better every deep_rarity_depth
## rooms deeper, never set rarity (set items come only from bosses).
func _dungeon_rarity(dungeon: DungeonDef, camp: int) -> int:
	var steps := floori(float(camps.sites.depth[camp]) / maxi(dungeon.deep_rarity_depth, 1))
	return mini(dungeon.min_drop_rarity + steps, loot_config.talisman_max_rarity)


## A dungeon room's Geon multiplier, growing with depth.
func _dungeon_geon(dungeon: DungeonDef, camp: int) -> float:
	return dungeon.geon_multiplier + dungeon.depth_geon_step * camps.sites.depth[camp]


## Spawner monsters drop rarely, one at a time: farming adds up.
func _on_spawner_kill(camp: int, at: Vector2, level: int) -> void:
	var dungeon := world.dungeon()
	if dungeon == null:
		return
	if _loot_rng.randf() < dungeon.spawner_drop_chance:
		_loot.drop_rewards(at, 1, level, _dungeon_rarity(dungeon, camp),
				_dungeon_geon(dungeon, camp))
	if _loot_rng.randf() < dungeon.spawner_geon_chance:
		_loot.place_geon(1, at)


func _on_location_entered(title: String, level: int, is_town: bool) -> void:
	var detail := "Safe haven" if is_town else "Level %d" % level
	_hud.banner("%s  -  %s" % [title.to_upper(), detail], Color(1.0, 0.85, 0.55),
			LOCATION_MESSAGE_TIME)


func _on_boss_killed(slot: int, at: Vector2) -> void:
	_effects.spawn(_pillar_effect, Vector3(at.x, 0.0, at.y), 2.0)
	if summons.is_summoned(slot):
		summons.on_killed(slot)
		_summoned_boss_rewards(at)
		return
	var level := world.level()
	_loot.drop_rewards(at, boss_config.extra_drops, level, boss_config.min_drop_rarity)
	var growth := 1.0 + loot_config.geon_growth_per_level * (level - 1)
	_loot.place_geon(roundi(boss_config.geon * growth), at)
	var dungeon := world.dungeon()
	if dungeon != null and set_list != null and dungeon.set_index >= 0 \
			and dungeon.set_index < set_list.sets.size() \
			and _loot_rng.randf() < set_list.boss_drop_chance:
		_loot.drop_set_piece(at, set_list, dungeon.set_index, level)
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


## The hero wears what's equipped (rebuilt only when the look changes).
func _dress_hero() -> void:
	_player.set_look(HeroLook.from_inventory(inventory, loot_config))


func _on_skill_locked(skill: int) -> void:
	var def := active_list.skills[skill]
	_feedback.skill_locked()
	_hud.toast("%s: learn it on CHAR from level %d" % [def.display_name, def.unlock_level],
			Color(1.0, 0.7, 0.4))


func _on_talisman_picked_up(id: int) -> void:
	var tier := TalismanRules.tier_of(id)
	_hud.toast("Picked up %s (%d)" % [TalismanRules.display_name(loot_config, id),
			inventory.talisman_count(id)], loot_config.rarity_colors[tier])
	_feedback.item_picked_up()


func _on_talisman_applied(success: bool, _gear: ItemData) -> void:
	_feedback.refined(success)


func _on_refined(result: Refinery.Result, _item: ItemData) -> void:
	if result == Refinery.Result.SUCCESS:
		_feedback.refined(true)
	elif result == Refinery.Result.DOWNGRADED or result == Refinery.Result.FAILED:
		_feedback.refined(false)


## Any monster, whatever its level, may drop a Blessed Stone where it fell.
## Any monster may drop a summoning shard where it fell.
func _roll_summon_shards(dead: int) -> void:
	var positions := _swarm.state.dead_positions
	for k in dead:
		if _loot_rng.randf() < summon_config.shard_drop_chance:
			_loot.place_shard(positions[k])


## Summons the boss if the player can (menu button). Shows why not otherwise.
func summon_boss() -> bool:
	var why := summons.blocker()
	if why != "":
		_hud.toast(why, Color(1.0, 0.6, 0.4))
		_feedback.skill_locked()
		return false
	return summons.summon()


func _on_boss_summoned(at: Vector2) -> void:
	_effects.spawn(_pillar_effect, Vector3(at.x, 0.0, at.y), 3.0)
	_feedback.boss_slam(false)
	_hud.banner("THE %s RISES  -  LEVEL %d" % [summon_config.boss_name.to_upper(),
			summons.level()], summon_config.color, 3.0)


## The summoned boss pays out far more than a camp boss.
func _summoned_boss_rewards(at: Vector2) -> void:
	var level := summons.level()
	_loot.drop_rewards(at, summon_config.reward_drops, level, summon_config.min_rarity, 2.0,
			summon_config.item_chance)
	_loot.drop_dread(at, summon_config.dread_drops, level)
	if _loot_rng.randf() < summon_config.legendary_chance:
		_loot.drop(at, 1, level, mini(4, loot_config.talisman_max_rarity))
	var growth := 1.0 + loot_config.geon_growth_per_level * (level - 1)
	_loot.place_geon(roundi(boss_config.geon * growth * summon_config.geon_multiplier), at)
	_hud.banner("%s SLAIN" % summon_config.boss_name.to_upper(), summon_config.color, 3.0)


func _on_shard_picked_up() -> void:
	_hud.toast("+1 %s (%d/%d)" % [summon_config.shard_name, inventory.summon_shards,
			summon_config.shards_needed], summon_config.shard_color)
	if inventory.summon_shards == summon_config.shards_needed:
		_hud.banner("ENOUGH %sS TO SUMMON THE %s" % [summon_config.shard_name.to_upper(),
				summon_config.boss_name.to_upper()], summon_config.color, 2.5)
	_feedback.item_picked_up()


func _roll_blessed_stones(dead: int) -> void:
	var positions := _swarm.state.dead_positions
	for k in dead:
		if _loot_rng.randf() < loot_config.blessed_drop_chance:
			_loot.place_blessed(positions[k])


func _on_blessed_picked_up() -> void:
	_hud.banner(loot_config.blessed_name.to_upper() + "!", loot_config.blessed_color, 2.0)
	_hud.toast("+1 %s - refining with it always succeeds" % loot_config.blessed_name,
			loot_config.blessed_color)
	_feedback.item_picked_up()


func _on_geon_picked_up(amount: int) -> void:
	_hud.toast("+%d %s" % [amount, loot_config.currency_name], loot_config.geon_color)


func _on_item_picked_up(item: ItemData) -> void:
	var equipped := inventory.is_equipped(item)
	var color := loot_config.rarity_colors[item.rarity]
	_hud.toast("%s %s" % ["Equipped" if equipped else "Picked up", item.item_name], color)
	if item.rarity >= loot_config.announce_rarity:
		_hud.banner("%s!  %s" % [loot_config.rarity_names[item.rarity].to_upper(),
				item.item_name.to_upper()], color, 2.0)
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


## The Egg Keeper in the town square: her model and name, standing with the
## open world's scenery (so she hides inside dungeons).
func _build_keeper() -> void:
	var keeper := Node3D.new()
	keeper.name = "EggKeeper"
	var at := world.map.town_spawn() + pet_config.keeper_offset
	keeper.position = Vector3(at.x, 0.0, at.y)
	keeper.rotation.y = PI * 0.75
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	var body := MeshInstance3D.new()
	body.mesh = CharacterModels.keeper(1.7, pet_config.keeper_color, material)
	keeper.add_child(body)
	var label := Label3D.new()
	label.text = "Egg Keeper"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 14
	label.modulate = Color(0.85, 1.0, 0.7)
	label.position = Vector3(0.0, 2.2, 0.0)
	keeper.add_child(label)
	_scenery.get_node("Overworld").add_child(keeper)


## Walking up to the Egg Keeper opens her eggs once; step away to reset.
func _check_keeper() -> void:
	if world.space != WorldMap.OVERWORLD or world.is_travelling() or _menu.is_open():
		return
	var keeper := world.map.town_spawn() + pet_config.keeper_offset
	var d := _player.ground_position().distance_to(keeper)
	if d <= pet_config.keeper_radius and not _keeper_engaged:
		_keeper_engaged = true
		_menu.open_keeper()
	elif d > pet_config.keeper_radius * 1.6:
		_keeper_engaged = false


func _on_quest_completed(quest: int) -> void:
	_hud.banner("QUEST COMPLETE", Color(1.0, 0.85, 0.4), 2.2)
	_hud.toast("%s - open PET to claim your reward" % quest_list.quests[quest].title,
			Color(1.0, 0.85, 0.4))
	_feedback.level_up()


func _on_egg_taken(egg: ItemData) -> void:
	var worn := inventory.is_equipped(egg)
	_hud.toast("%s %s" % ["Your pet:" if worn else "In your backpack:", egg.item_name],
			loot_config.rarity_colors[egg.rarity])


func _on_pet_evolved(pet: ItemData, stage: int) -> void:
	var text := "%s HATCHED!" % pet.item_name.to_upper() if stage == 1 \
			else "EVOLVED INTO %s" % pet.item_name.to_upper()
	_hud.banner(text, Color(1.0, 0.9, 0.5), 2.4)
	_effects.spawn(_pillar_effect, pets.position, 0.8)
	_feedback.level_up()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_swarm.spawn_around(_player.ground_position(), _swarm.config.debug_spawn_batch)
