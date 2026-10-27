class_name PlayerCombat
extends RefCounted
## Turns attack input into abilities: aimed bolts, the nova pulse around the
## player (costs mana) and the lure war cry (costs mana: wakes camps in range
## and hurries awake enemies toward the player). Kills give mana back.
## Owns only cooldowns and costs; damage goes through SwarmManager, bolts
## through ProjectileSystem and camp waking through ZoneDirector.
## Job perks change the abilities: aftershocks after the nova (Stormcaller),
## marks, faster cooldown and armor from the lure (Warlord), piercing
## bigger bolts (Arcanist).

signal nova_cast(center: Vector2)
signal lure_cast(center: Vector2, camps_woken: int)
signal bolt_fired
signal aftershock(center: Vector2)
## An ability was pressed but there wasn't enough mana.
signal out_of_mana

const MAX_AFTERSHOCKS := 8

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
## Queued aftershocks: swarm time due, center, radius, damage. Fixed size.
var _shock_due: PackedFloat32Array = []
var _shock_center: PackedVector2Array = []
var _shock_radius: PackedFloat32Array = []
var _shock_damage: PackedFloat32Array = []
var _shock_count := 0


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
	for k in MAX_AFTERSHOCKS:
		_shock_due.append(0.0)
		_shock_center.append(Vector2.ZERO)
		_shock_radius.append(0.0)
		_shock_damage.append(0.0)


## Call between SwarmManager.simulate() and resolve_deaths().
func tick(delta: float) -> void:
	bolt_cooldown.duration = _bolt.fire_interval / _mult(PlayerStat.Id.FIRE_RATE)
	_projectiles.damage_multiplier = _mult(PlayerStat.Id.BOLT_DAMAGE)
	var perks := _perks()
	_projectiles.pierce = perks.bolt_pierce if perks != null else 0
	_projectiles.burst_radius_multiplier = perks.burst_radius_multiplier if perks != null else 1.0
	if _lure != null:
		lure_cooldown.duration = _lure.cooldown * (perks.lure_cooldown_multiplier
				if perks != null else 1.0)
	_swarm.mark_damage_bonus = perks.mark_damage_bonus if perks != null else 0.0
	_run_aftershocks()
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
	var damage := _nova.damage * _mult(PlayerStat.Id.NOVA_DAMAGE)
	_swarm.damage_circle(center, radius, damage, _nova.knockback)
	_effects.spawn(_nova_effect, Vector3(center.x, 0.0, center.y), radius)
	var perks := _perks()
	if perks != null:
		for n in perks.nova_aftershocks:
			_queue_aftershock(_swarm.now() + perks.aftershock_delay * (n + 1), center,
					radius * pow(perks.aftershock_radius_multiplier, n + 1),
					damage * perks.aftershock_damage_multiplier)


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
	var perks := _perks()
	if perks != null:
		if perks.lure_mark_duration > 0.0:
			_swarm.mark_within(center, radius, perks.lure_mark_duration)
		if perks.lure_armor > 0.0:
			_player.vitals.grant_armor(perks.lure_armor, _swarm.now() + perks.lure_armor_duration)
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


func _perks() -> JobPerks:
	return _stats.perks if _stats != null else null


func _queue_aftershock(due: float, center: Vector2, radius: float, damage: float) -> void:
	if _shock_count >= MAX_AFTERSHOCKS:
		return
	_shock_due[_shock_count] = due
	_shock_center[_shock_count] = center
	_shock_radius[_shock_count] = radius
	_shock_damage[_shock_count] = damage
	_shock_count += 1


func _run_aftershocks() -> void:
	var now := _swarm.now()
	for k in range(_shock_count - 1, -1, -1):
		if _shock_due[k] > now:
			continue
		var center := _shock_center[k]
		var radius := _shock_radius[k]
		_swarm.damage_circle(center, radius, _shock_damage[k], _nova.knockback * 0.6)
		_effects.spawn(_nova_effect, Vector3(center.x, 0.0, center.y), radius)
		aftershock.emit(center)
		var last := _shock_count - 1
		_shock_due[k] = _shock_due[last]
		_shock_center[k] = _shock_center[last]
		_shock_radius[k] = _shock_radius[last]
		_shock_damage[k] = _shock_damage[last]
		_shock_count = last


func pending_aftershocks() -> int:
	return _shock_count


func _mult(stat: int) -> float:
	return _stats.multiplier(stat) if _stats != null else 1.0
