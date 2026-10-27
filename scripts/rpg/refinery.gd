class_name Refinery
extends RefCounted
## Risky item upgrades. Each attempt costs stones; success raises the item
## one level, failure drops it one level (never below +0, never destroyed).
## Odds fall as the level rises, and each failure in a row adds a little
## "pity" to the next chance, so bad streaks end.

enum Result { SUCCESS, DOWNGRADED, FAILED, NOT_ENOUGH_STONES, MAXED }

var _config: LootConfig
var _rng := RandomNumberGenerator.new()


func _init(config: LootConfig, seed_value: int = 0) -> void:
	_config = config
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func is_maxed(item: ItemData) -> bool:
	return item.upgrade_level >= _config.upgrade_max


func cost_for(item: ItemData) -> int:
	return _config.upgrade_cost_base + _config.upgrade_cost_per_level * item.upgrade_level


## Chance of reaching the next level, including pity from earlier failures.
func chance_for(item: ItemData) -> float:
	if is_maxed(item):
		return 0.0
	var base: float = _config.upgrade_chances[mini(item.upgrade_level,
			_config.upgrade_chances.size() - 1)]
	return minf(base + _config.upgrade_pity_per_fail * item.fail_streak, 1.0)


func attempt(item: ItemData, inventory: Inventory) -> Result:
	if is_maxed(item):
		return Result.MAXED
	var cost := cost_for(item)
	if inventory.stones < cost:
		return Result.NOT_ENOUGH_STONES
	inventory.stones -= cost
	var result: Result
	if _rng.randf() < chance_for(item):
		item.upgrade_level += 1
		item.fail_streak = 0
		result = Result.SUCCESS
	else:
		item.fail_streak += 1
		if item.upgrade_level > 0:
			item.upgrade_level -= 1
			result = Result.DOWNGRADED
		else:
			result = Result.FAILED
	inventory.notify_changed()
	return result
