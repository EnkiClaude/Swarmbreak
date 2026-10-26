class_name PlayerCombat
extends RefCounted
## Turns attack input into abilities: aimed bolts, the nova pulse around the
## player (costs mana) and the lure war cry (costs mana: wakes camps in range
## and hurries awake enemies toward the player). Kills give mana back.
## Owns only cooldowns and costs; damage goes through SwarmManager, bolts
## through ProjectileSystem and camp waking through ZoneDirector.

signal nova_cast(center: Vector2)
signal lure_cast(center: Vector2, camps_woken: int)
signal bolt_fired
## An ability was pressed but there wasn't enough mana.
signal out_of_mana

var nova_cooldown: Cooldown
var lure_cooldown: Cooldown
var bolt_cooldown: Cooldown

var _player: Player
var _swarm: SwarmManager
var _projectiles: ProjectileSystem
var _effects: EffectSystem
var _zone: ZoneDirector
var _nova: NovaConfig
var _bolt: BoltConfig
var _lure: LureConfig
var _nova_effect := -1
var _lure_effect := -1
var _stats: PlayerStats


func _init(player: Player, swarm: SwarmManager, projectiles: ProjectileSystem,
		effects: EffectSystem, zone: ZoneDirector = null, stats: PlayerStats = null) -> void:
	_player = player
	_swarm = swarm
	_projectiles = projectiles
	_effects = effects
	_zone = zone
	_stats = stats
	_nova = player.config.nova
	_bolt = player.config.bolt
	_lure = player.config.lure
	nova_cooldown = Cooldown.new(_nova.cooldown)
	lure_cooldown = Cooldown.new(_lure.cooldown if _lure != null else 1.0)
	bolt_cooldown = Cooldown.new(_bolt.fire_interval)
	_nova_effect = effects.register(_nova.effect)
	if _lure != null:
		_lure_effect = effects.register(_lure.effect)
	swarm.enemies_killed.connect(_on_enemies_killed)


## Call between SwarmManager.simulate() and resolve_deaths().
func tick(delta: float) -> void:
	bolt_cooldown.duration = _bolt.fire_interval / _mult(PlayerStat.Id.FIRE_RATE)
	_projectiles.damage_multiplier = _mult(PlayerStat.Id.BOLT_DAMAGE)
	nova_cooldown.tick(delta)
	lure_cooldown.tick(delta)
	bolt_cooldown.tick(delta)
	if Input.is_action_just_pressed("attack_nova") or (
			Input.is_action_pressed("attack_nova") and nova_cooldown.is_ready()):
		_try_nova()
	if _lure != null and Input.is_action_just_pressed("skill_lure"):
		_try_lure()
	if _wants_to_fire() and bolt_cooldown.is_ready():
		bolt_cooldown.trigger()
		var aim := _player.aim_direction
		if _projectiles.fire(_player.ground_position(), Vector2(aim.x, aim.z)):
			bolt_fired.emit()


func _try_nova() -> void:
	if not nova_cooldown.is_ready():
		return
	if not _player.vitals.spend_mana(_nova.mana_cost):
		if Input.is_action_just_pressed("attack_nova"):
			out_of_mana.emit()
		return
	nova_cooldown.trigger()
	var center := _player.ground_position()
	nova_cast.emit(center)
	var radius := _nova.radius * _mult(PlayerStat.Id.NOVA_RADIUS)
	_swarm.damage_circle(center, radius, _nova.damage * _mult(PlayerStat.Id.NOVA_DAMAGE),
			_nova.knockback)
	_effects.spawn(_nova_effect, Vector3(center.x, 0.0, center.y), radius)


func _try_lure() -> void:
	if not lure_cooldown.is_ready():
		return
	if not _player.vitals.spend_mana(_lure.mana_cost):
		out_of_mana.emit()
		return
	lure_cooldown.trigger()
	var center := _player.ground_position()
	var radius := _lure.radius * _mult(PlayerStat.Id.LURE_RADIUS)
	var woken := _zone.lure(center, radius) if _zone != null else 0
	_swarm.boost_within(center, radius, _lure.boost_duration)
	_effects.spawn(_lure_effect, Vector3(center.x, 0.0, center.y), radius)
	lure_cast.emit(center, woken)


func _wants_to_fire() -> bool:
	if Input.is_action_pressed("attack_fire"):
		return true
	return _bolt.auto_fire_on_aim and _player.is_stick_aiming()


func _on_enemies_killed(count: int, _center: Vector2) -> void:
	var per_kill := _player.config.mana_per_kill
	if _stats != null:
		per_kill += _stats.value(PlayerStat.Id.MANA_PER_KILL)
	_player.vitals.gain_mana(per_kill * count)


func _mult(stat: int) -> float:
	return _stats.multiplier(stat) if _stats != null else 1.0
