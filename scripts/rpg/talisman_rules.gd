class_name TalismanRules
extends RefCounted
## Talismans: a kind (LootConfig.talismans) at a tier (a rarity), stored as
## one id (kind * TIERS + tier) and counted in Inventory.talismans, so equal
## talismans stack. Their stats are fixed per kind and tier, never rolled.
## Each item has sockets by rarity (LootConfig.talisman_sockets); applying a
## talisman to a free socket uses one up whatever happens and succeeds at a
## chance that falls with each talisman already on the item. Success adds
## its stats to the item for good; failure only loses the talisman. Gear is
## never harmed.

enum Result { SUCCESS, FAILED, NO_SOCKET, INVALID }

## Room for tiers per kind in an id (more than any rarity count).
const TIERS := 8

var _config: LootConfig
var _rng := RandomNumberGenerator.new()


func _init(config: LootConfig, seed_value: int = 0) -> void:
	_config = config
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


static func id_of(kind: int, tier: int) -> int:
	return kind * TIERS + tier


static func kind_of(id: int) -> int:
	return floori(float(id) / TIERS)


static func tier_of(id: int) -> int:
	return id % TIERS


## True if the id names a talisman the config has.
static func is_valid(config: LootConfig, id: int) -> bool:
	return id >= 0 and kind_of(id) < config.talismans.size() \
			and tier_of(id) <= config.talisman_max_rarity


## "Rare Talisman of Fury".
static func display_name(config: LootConfig, id: int) -> String:
	return "%s %s of %s" % [config.rarity_names[tier_of(id)], config.talisman_name,
			config.talismans[kind_of(id)].talisman_name]


static func build_hint(config: LootConfig, id: int) -> String:
	return config.talismans[kind_of(id)].build_hint


static func stats_of(config: LootConfig, id: int) -> PackedInt32Array:
	return config.talismans[kind_of(id)].stats


## Its values: the kind's base values times its tier's power.
static func values_of(config: LootConfig, id: int) -> PackedFloat32Array:
	var def := config.talismans[kind_of(id)]
	var tier := tier_of(id)
	var power: float = config.talisman_tier_power[mini(tier,
			config.talisman_tier_power.size() - 1)]
	var out := PackedFloat32Array()
	for k in def.values.size():
		var v := def.values[k] * power
		# Keep them tidy: whole percents, or one decimal for flat stats.
		if PlayerStat.IS_PERCENT[def.stats[k]] != 0:
			v = roundf(v * 1000.0) / 1000.0
		else:
			v = roundf(v * 10.0) / 10.0
		out.append(v)
	return out


## Its stats as text lines.
static func describe_lines(config: LootConfig, id: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var stats := stats_of(config, id)
	var values := values_of(config, id)
	for k in stats.size():
		lines.append(PlayerStat.describe(stats[k], values[k]))
	return lines


## Sockets an item has (0 for pets).
static func sockets_of(config: LootConfig, item: ItemData) -> int:
	if item == null or item.is_pet() or config.talisman_sockets.is_empty():
		return 0
	return config.talisman_sockets[clampi(item.rarity, 0, config.talisman_sockets.size() - 1)]


func sockets(item: ItemData) -> int:
	return sockets_of(_config, item)


func free_sockets(item: ItemData) -> int:
	return maxi(sockets(item) - item.talisman_sockets_used, 0)


## Chance the next talisman on this item takes.
func chance_for(item: ItemData) -> float:
	if free_sockets(item) <= 0 or _config.talisman_chances.is_empty():
		return 0.0
	return _config.talisman_chances[mini(item.talisman_sockets_used,
			_config.talisman_chances.size() - 1)]


## Applies one talisman of the id from the inventory to gear. It's used up
## unless the attempt can't be made (INVALID, NO_SOCKET).
func apply(id: int, gear: ItemData, inventory: Inventory) -> Result:
	if gear == null or not is_valid(_config, id) or inventory.talisman_count(id) <= 0:
		return Result.INVALID
	if free_sockets(gear) <= 0:
		return Result.NO_SOCKET
	var chance := chance_for(gear)
	inventory.take_talisman(id)
	var result := Result.FAILED
	if _rng.randf() < chance:
		gear.talisman_sockets_used += 1
		gear.talisman_stats.append_array(stats_of(_config, id))
		gear.talisman_values.append_array(values_of(_config, id))
		result = Result.SUCCESS
	inventory.notify_changed()
	return result


## Essence one talisman of the id dissolves into.
static func essence_of(config: LootConfig, id: int) -> int:
	var tiers := config.essence_per_tier
	return tiers[clampi(tier_of(id), 0, tiers.size() - 1)] if not tiers.is_empty() else 0


## Dissolves up to count talismans of the id into essence. Returns the essence gained.
func dissolve(id: int, count: int, inventory: Inventory) -> int:
	var gained := 0
	for _n in count:
		if not inventory.take_talisman(id):
			break
		gained += essence_of(_config, id)
	inventory.essence += gained
	inventory.notify_changed()
	return gained


## Essence the next Scroll of Power costs.
func scroll_cost(inventory: Inventory) -> int:
	return roundi(_config.scroll_cost_base * (1.0 + _config.scroll_cost_growth
			* inventory.scrolls_bought))


## Binds a Scroll of Power: spends essence for one attribute point.
func bind_scroll(inventory: Inventory, progress: PlayerProgress) -> bool:
	var cost := scroll_cost(inventory)
	if inventory.essence < cost:
		return false
	inventory.essence -= cost
	inventory.scrolls_bought += 1
	progress.attribute_points += 1
	progress.attributes_changed.emit()
	inventory.notify_changed()
	return true


## A random talisman: any kind, a tier rolled like an item's rarity (at
## least min_tier, at most talisman_max_rarity).
func roll(min_tier: int = 0) -> int:
	var total := 0.0
	var weights := _config.rarity_weights
	for t in mini(weights.size(), _config.talisman_max_rarity + 1):
		total += weights[t]
	var r := _rng.randf() * total
	var tier := 0
	for t in mini(weights.size(), _config.talisman_max_rarity + 1):
		r -= weights[t]
		if r <= 0.0:
			tier = t
			break
	tier = clampi(maxi(tier, min_tier), 0, _config.talisman_max_rarity)
	return id_of(_rng.randi() % maxi(_config.talismans.size(), 1), tier)
