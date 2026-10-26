class_name PlayerVitals
extends RefCounted
## The player's health and mana. Both regenerate; damage is ignored while
## invulnerable (during and just after a dodge) and reduced by armor.
## Maxima and regen come from the base config plus PlayerStats.

var health: float
var mana: float
var max_health: float
var max_mana: float
## Swarm time until which damage is ignored.
var invulnerable_until := 0.0

var _config: PlayerConfig
var _stats: PlayerStats


func _init(config: PlayerConfig, stats: PlayerStats = null) -> void:
	_config = config
	_stats = stats
	refresh_maxima()
	reset()


## Re-reads maxima after stats change, keeping current values in range.
func refresh_maxima() -> void:
	max_health = _config.max_health + _stat(PlayerStat.Id.MAX_HEALTH)
	max_mana = _config.max_mana + _stat(PlayerStat.Id.MAX_MANA)
	health = minf(health, max_health)
	mana = minf(mana, max_mana)


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
	var health_regen := _config.health_regen + _stat(PlayerStat.Id.HEALTH_REGEN)
	var mana_regen := _config.mana_regen * (1.0 + _stat(PlayerStat.Id.MANA_REGEN))
	health = minf(health + health_regen * delta, max_health)
	mana = minf(mana + mana_regen * delta, max_mana)


## Returns the damage actually taken.
func take_damage(amount: float, now: float) -> float:
	if amount <= 0.0 or is_dead() or is_invulnerable(now):
		return 0.0
	var taken := minf(amount * (1.0 - _stat(PlayerStat.Id.ARMOR)), health)
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


func _stat(stat: int) -> float:
	return _stats.value(stat) if _stats != null else 0.0
