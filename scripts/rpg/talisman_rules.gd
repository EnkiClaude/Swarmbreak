class_name TalismanRules
extends RefCounted
## Applying talismans to gear. Each item has sockets by rarity
## (LootConfig.talisman_sockets); applying a talisman to a free socket costs
## the talisman whatever happens and succeeds at a chance that falls with
## each talisman already on the item. Success adds the talisman's stats to
## the item for good; failure only loses the talisman. Gear is never harmed.

enum Result { SUCCESS, FAILED, NO_SOCKET, INVALID }

var _config: LootConfig
var _rng := RandomNumberGenerator.new()


func _init(config: LootConfig, seed_value: int = 0) -> void:
	_config = config
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Sockets an item has (0 for talismans and pets).
static func sockets_of(config: LootConfig, item: ItemData) -> int:
	if item == null or item.is_talisman or item.is_pet() or config.talisman_sockets.is_empty():
		return 0
	return config.talisman_sockets[clampi(item.rarity, 0, config.talisman_sockets.size() - 1)]


func sockets(item: ItemData) -> int:
	return sockets_of(_config, item)


## Talismans applied to an item: one per socket used.
func used(item: ItemData) -> int:
	return item.talisman_sockets_used


func free_sockets(item: ItemData) -> int:
	return maxi(sockets(item) - used(item), 0)


## Chance the next talisman on this item takes.
func chance_for(item: ItemData) -> float:
	if free_sockets(item) <= 0 or _config.talisman_chances.is_empty():
		return 0.0
	return _config.talisman_chances[mini(used(item), _config.talisman_chances.size() - 1)]


## Applies a backpack talisman to gear. The talisman is used up unless the
## attempt can't be made (INVALID, NO_SOCKET).
func apply(talisman: ItemData, gear: ItemData, inventory: Inventory) -> Result:
	if talisman == null or gear == null or not talisman.is_talisman or gear.is_talisman \
			or not inventory.backpack.has(talisman):
		return Result.INVALID
	if free_sockets(gear) <= 0:
		return Result.NO_SOCKET
	var chance := chance_for(gear)
	inventory.backpack.erase(talisman)
	var result := Result.FAILED
	if _rng.randf() < chance:
		gear.talisman_sockets_used += 1
		for k in talisman.stats.size():
			gear.talisman_stats.append(talisman.stats[k])
			gear.talisman_values.append(talisman.values[k])
		result = Result.SUCCESS
	inventory.notify_changed()
	return result
