class_name Refinery
extends RefCounted
## Item upgrades that get harder every level. Each attempt costs Geon and
## succeeds at the level's chance (upgrade_chances, falling steeply toward
## +10); success raises the item one level, failure leaves it as it was
## (never lower, never destroyed). Each failure in a row adds a little
## "pity" to the next chance, so bad streaks end. A Blessed Stone instead of
## Geon makes an attempt certain to succeed. DOWNGRADED is no longer used.

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
		# A failure keeps the level; it only costs the Geon (and adds pity).
		item.fail_streak += 1
		result = Result.FAILED
	inventory.notify_changed()
	return result


## Spends one Blessed Stone for a certain success.
func attempt_blessed(item: ItemData, inventory: Inventory) -> Result:
	if is_maxed(item):
		return Result.MAXED
	if inventory.blessed_stones <= 0:
		return Result.NOT_ENOUGH_STONES
	inventory.blessed_stones -= 1
	item.upgrade_level += 1
	item.fail_streak = 0
	inventory.notify_changed()
	return Result.SUCCESS
