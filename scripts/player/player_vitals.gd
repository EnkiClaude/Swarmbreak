class_name PlayerVitals
extends RefCounted
## The player's health and mana. Both regenerate; damage is ignored while
## invulnerable (during and just after a dodge).

var health: float
var mana: float
var max_health: float
var max_mana: float
## Swarm time until which damage is ignored.
var invulnerable_until := 0.0

var _config: PlayerConfig


func _init(config: PlayerConfig) -> void:
	_config = config
	max_health = config.max_health
	max_mana = config.max_mana
	reset()


func reset() -> void:
	health = max_health
	mana = max_mana
	invulnerable_until = 0.0


func is_dead() -> bool:
	return health <= 0.0


func is_invulnerable(now: float) -> bool:
	return now < invulnerable_until


func tick(delta: float) -> void:
	if is_dead():
		return
	health = minf(health + _config.health_regen * delta, max_health)
	mana = minf(mana + _config.mana_regen * delta, max_mana)


## Returns the damage actually taken.
func take_damage(amount: float, now: float) -> float:
	if amount <= 0.0 or is_dead() or is_invulnerable(now):
		return 0.0
	var taken := minf(amount, health)
	health -= taken
	return taken


## Spends mana if there is enough. Returns whether it was spent.
func spend_mana(cost: float) -> bool:
	if mana < cost:
		return false
	mana -= cost
	return true


func gain_mana(amount: float) -> void:
	mana = minf(mana + amount, max_mana)
