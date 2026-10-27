class_name CombatFeedback
extends Node
## Makes hits feel like hits. Listens to combat events and answers with
## hit-stop, camera shake, the break popup, sound and vibration, all scaled by
## how many enemies a single blow killed. main.gd asks consume_hitstop()
## each frame and freezes the simulation while it returns true.

var hitstop_remaining := 0.0

var _config: FeedbackConfig
var _audio: AudioConfig
var _camera: CameraRig
var _popup: BreakPopup
var _sfx: SfxPlayer
var _bank: SfxBank
var _hurt_cooldown := 0.0


func setup(config: FeedbackConfig, audio: AudioConfig, camera: CameraRig, popup: BreakPopup,
		sfx: SfxPlayer, swarm: SwarmManager, combat: PlayerCombat,
		projectiles: ProjectileSystem, player: Player = null) -> void:
	_config = config
	_audio = audio
	_camera = camera
	_popup = popup
	_sfx = sfx
	_bank = SfxBank.new()
	swarm.enemies_killed.connect(_on_enemies_killed)
	combat.nova_cast.connect(_on_nova_cast)
	combat.bolt_fired.connect(_on_bolt_fired)
	projectiles.bolt_burst.connect(_on_bolt_burst)
	combat.lure_cast.connect(_on_lure_cast)
	combat.aftershock.connect(func(_center: Vector2) -> void: aftershock())
	combat.out_of_mana.connect(_on_out_of_mana)
	if player != null:
		player.dashed.connect(_on_dashed)


## The player took damage this frame (called by main).
func player_hurt(amount: float, delta: float) -> void:
	_hurt_cooldown -= delta
	_camera.add_trauma(_config.shake_per_damage * amount)
	if _hurt_cooldown <= 0.0:
		_hurt_cooldown = _audio.hurt_interval
		_sfx.play(_bank.hurt, _audio.hurt_db)


## Counts down the freeze. True while the game should stay frozen this frame.
func consume_hitstop(delta: float) -> bool:
	if hitstop_remaining <= 0.0:
		return false
	hitstop_remaining -= delta
	return true


## Freeze length for one blow that killed this many enemies.
static func hitstop_for(config: FeedbackConfig, kills: int) -> float:
	if kills < config.hitstop_min_kills:
		return 0.0
	return minf(config.hitstop_base + config.hitstop_per_kill * kills, config.hitstop_max)


func _on_enemies_killed(count: int, _center: Vector2) -> void:
	hitstop_remaining = maxf(hitstop_remaining, hitstop_for(_config, count))
	_camera.add_trauma(minf(_config.shake_per_kill * count, _config.shake_kills_max))
	_popup.show_break(count)
	var doublings := log(float(count)) / log(2.0)
	_sfx.play(_bank.kill, minf(_audio.kill_db + doublings * _audio.kill_db_per_doubling,
			_audio.kill_db_max))
	_vibrate(_config.vibration_per_kill * count)


func _on_nova_cast(_center: Vector2) -> void:
	_camera.add_trauma(_config.shake_nova)
	_sfx.play(_bank.nova, _audio.nova_db)
	_vibrate(_config.vibration_nova)


## A boss slam landed (shake either way; it's loud).
func boss_slam(hit_player: bool) -> void:
	_camera.add_trauma(_config.shake_nova * (1.2 if hit_player else 0.7))
	_sfx.play(_bank.nova, _audio.nova_db - 3.0)
	_vibrate(_config.vibration_nova)


func aftershock() -> void:
	_camera.add_trauma(_config.shake_nova * 0.6)
	_sfx.play(_bank.bolt_burst, _audio.nova_db)


func refined(success: bool) -> void:
	_sfx.play(_bank.level_up if success else _bank.denied,
			_audio.level_up_db if success else _audio.denied_db)


func level_up() -> void:
	_sfx.play(_bank.level_up, _audio.level_up_db)


func item_picked_up() -> void:
	_sfx.play(_bank.pickup, _audio.pickup_db)


func _on_lure_cast(_center: Vector2, _camps_woken: int) -> void:
	_camera.add_trauma(_config.shake_lure)
	_sfx.play(_bank.lure, _audio.lure_db)
	_vibrate(_config.vibration_nova * 0.5)


func _on_dashed() -> void:
	_sfx.play(_bank.dodge, _audio.dodge_db)


func _on_out_of_mana() -> void:
	_sfx.play(_bank.denied, _audio.denied_db)


func _on_bolt_fired() -> void:
	_sfx.play(_bank.bolt_fire, _audio.bolt_fire_db)


func _on_bolt_burst(_at: Vector2) -> void:
	_camera.add_trauma(_config.shake_bolt_burst)
	_sfx.play(_bank.bolt_burst, _audio.bolt_burst_db)


func _vibrate(strength: float) -> void:
	if not _config.vibration_enabled or strength <= 0.0:
		return
	var s := minf(strength, _config.vibration_max)
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, s * 0.6, s, _config.vibration_duration)
	if DisplayServer.is_touchscreen_available():
		Input.vibrate_handheld(roundi(_config.vibration_duration * 1000.0 * s), s)
