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

const ZONE_MESSAGE_TIME := 2.0
const START_POSITION := Vector3.ZERO

@export var feedback_config: FeedbackConfig
@export var audio_config: AudioConfig
@export var zone_config: ZoneConfig

var combat: PlayerCombat
var zone: ZoneDirector

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
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	var half_extent := _arena.config.half_extent
	_player.setup(_camera_rig, half_extent)
	_camera_rig.follow(_player)
	_corpses.setup(_swarm.config.enemy_types, feedback_config)
	_swarm.setup(half_extent, _effects, _corpses, zone_config.max_camps)
	_projectiles.setup(_player.config.bolt, _effects, half_extent)
	zone = ZoneDirector.new(zone_config, _swarm, half_extent)
	combat = PlayerCombat.new(_player, _swarm, _projectiles, _effects, zone)
	_sfx.setup(audio_config)
	_popup.setup(feedback_config)
	_feedback.setup(feedback_config, audio_config, _camera_rig, _popup, _sfx, _swarm, combat,
			_projectiles, _player)
	_hud.setup(_player.vitals, zone, _player, half_extent)
	_overlay.swarm = _swarm
	_overlay.combat = combat
	start_zone(1)


## Resets the player and spawns the given level's camps.
func start_zone(level: int) -> void:
	_restart_in = -1.0
	zone.generate(level, Vector2(START_POSITION.x, START_POSITION.z))
	_player.reset_to(START_POSITION)
	_player.vitals.reset()
	_camera_rig.follow(_player)
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
	zone.tick(player_pos)
	_update_player_health(dt, now, alive)
	_update_zone_flow(dt)
	_swarm.draw()
	_effects.tick(dt)
	_corpses.tick(dt)
	_popup.tick(dt)
	_hud.tick(dt)
	_camera_rig.tick(dt)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_swarm.spawn_around(_player.ground_position(), _swarm.config.debug_spawn_batch)
