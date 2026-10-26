extends Node3D
## Wires the arena scene together and ticks systems in a fixed order each frame:
##   player -> swarm.simulate -> player attacks -> bolts -> swarm.resolve_deaths
##   -> swarm.draw -> effects -> corpses -> popup -> camera
## Damage has to land between simulate() and resolve_deaths(), while enemy
## indices still match the spatial hash. During hit-stop only the camera
## (shake) and the break popup advance.

@export var feedback_config: FeedbackConfig
@export var audio_config: AudioConfig

var combat: PlayerCombat

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
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	var half_extent := _arena.config.half_extent
	_player.setup(_camera_rig, half_extent)
	_camera_rig.follow(_player)
	_corpses.setup(_swarm.config.enemy_types, feedback_config)
	_swarm.setup(half_extent, _effects, _corpses)
	_projectiles.setup(_player.config.bolt, _effects, half_extent)
	combat = PlayerCombat.new(_player, _swarm, _projectiles, _effects)
	_sfx.setup(audio_config)
	_popup.setup(feedback_config)
	_feedback.setup(feedback_config, audio_config, _camera_rig, _popup, _sfx, _swarm, combat,
			_projectiles)
	_swarm.spawn_around(_player.ground_position(), _swarm.config.initial_count)
	_overlay.swarm = _swarm
	_overlay.combat = combat


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	var dt := minf(delta, _swarm.config.max_tick_delta)
	if _feedback.consume_hitstop(dt):
		_popup.tick(dt)
		_camera_rig.tick(dt)
		return
	_player.tick(dt)
	_swarm.simulate(dt, _player.ground_position(), _player.config.radius)
	combat.tick(dt)
	_projectiles.tick(dt, _swarm)
	_swarm.resolve_deaths()
	_swarm.draw()
	_effects.tick(dt)
	_corpses.tick(dt)
	_popup.tick(dt)
	_camera_rig.tick(dt)
	_overlay.sim_usec = Time.get_ticks_usec() - start


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_swarm.spawn_around(_player.ground_position(), _swarm.config.debug_spawn_batch)
