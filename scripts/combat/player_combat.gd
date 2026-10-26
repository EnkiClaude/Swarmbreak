class_name PlayerCombat
extends RefCounted
## Turns attack input into abilities: the nova pulse around the player and
## aimed bolts. Owns only the cooldowns; damage goes through SwarmManager and
## bolts through ProjectileSystem.

signal nova_cast(center: Vector2)
signal bolt_fired

var nova_cooldown: Cooldown
var bolt_cooldown: Cooldown

var _player: Player
var _swarm: SwarmManager
var _projectiles: ProjectileSystem
var _effects: EffectSystem
var _nova: NovaConfig
var _bolt: BoltConfig
var _nova_effect := -1


func _init(player: Player, swarm: SwarmManager, projectiles: ProjectileSystem,
		effects: EffectSystem) -> void:
	_player = player
	_swarm = swarm
	_projectiles = projectiles
	_effects = effects
	_nova = player.config.nova
	_bolt = player.config.bolt
	nova_cooldown = Cooldown.new(_nova.cooldown)
	bolt_cooldown = Cooldown.new(_bolt.fire_interval)
	_nova_effect = effects.register(_nova.effect)


## Call between SwarmManager.simulate() and resolve_deaths().
func tick(delta: float) -> void:
	nova_cooldown.tick(delta)
	bolt_cooldown.tick(delta)
	if Input.is_action_pressed("attack_nova") and nova_cooldown.is_ready():
		nova_cooldown.trigger()
		_cast_nova()
	if _wants_to_fire() and bolt_cooldown.is_ready():
		bolt_cooldown.trigger()
		var aim := _player.aim_direction
		if _projectiles.fire(_player.ground_position(), Vector2(aim.x, aim.z)):
			bolt_fired.emit()


func _cast_nova() -> void:
	var center := _player.ground_position()
	_swarm.damage_circle(center, _nova.radius, _nova.damage, _nova.knockback)
	_effects.spawn(_nova_effect, Vector3(center.x, 0.0, center.y), _nova.radius)
	nova_cast.emit(center)


func _wants_to_fire() -> bool:
	if Input.is_action_pressed("attack_fire"):
		return true
	return _bolt.auto_fire_on_aim and _player.is_stick_aiming()
