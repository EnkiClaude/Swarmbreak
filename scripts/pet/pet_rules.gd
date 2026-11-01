class_name PetRules
extends RefCounted
## Pet maths on egg items (ItemData with slot PET): stage from level, the XP
## curve, the share of kill XP, levelling, and the stats and name a pet has
## at its level. Pure functions, so they're easy to test.


static func stage(config: PetConfig, level: int) -> int:
	@warning_ignore("integer_division")
	return mini(level / config.levels_per_stage, config.max_stage)


static func is_hatched(config: PetConfig, level: int) -> bool:
	return stage(config, level) >= 1


## How far around the player the pet collects loot: nothing as an egg, then
## a metre more every level.
static func pickup_radius(config: PetConfig, level: int) -> float:
	if not is_hatched(config, level):
		return 0.0
	return config.pickup_radius_base + config.pickup_radius_per_level * level


static func xp_to_next(config: PetConfig, level: int) -> float:
	return config.xp_first_level * pow(config.xp_growth, level - 1) \
			* pow(config.stage_xp_multiplier, stage(config, level))


## Fraction of the player's kill XP the pet gets at this level.
static func xp_share(config: PetConfig, level: int) -> float:
	return config.xp_share_base + config.xp_share_per_stage * stage(config, level)


## A level 1 egg of pet kind `kind`.
static func make_egg(config: PetConfig, kind: int) -> ItemData:
	var item := ItemData.new()
	item.slot = AffixDef.Slot.PET
	item.rarity = config.egg_rarity
	item.pet_type = kind
	item.pet_level = 1
	refresh(config, item)
	return item


## Rewrites the item's name and stats for its kind and level.
static func refresh(config: PetConfig, item: ItemData) -> void:
	var def := config.pets[clampi(item.pet_type, 0, config.pets.size() - 1)]
	var s := stage(config, item.pet_level)
	item.item_name = def.stage_names[mini(s, def.stage_names.size() - 1)]
	item.item_level = item.pet_level
	item.stats = PackedInt32Array()
	item.values = PackedFloat32Array()
	for k in def.stats.size():
		item.stats.append(def.stats[k])
		item.values.append(def.base_values[k] + def.per_level[k] * (item.pet_level - 1))


## Adds XP; returns how many levels it gained.
static func gain_xp(config: PetConfig, item: ItemData, amount: float) -> int:
	if item.pet_level >= config.max_level:
		return 0
	item.pet_xp += amount
	var gained := 0
	while item.pet_level < config.max_level and item.pet_xp >= xp_to_next(config, item.pet_level):
		item.pet_xp -= xp_to_next(config, item.pet_level)
		item.pet_level += 1
		gained += 1
	if gained > 0:
		refresh(config, item)
	return gained
