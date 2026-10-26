class_name ItemGenerator
extends RefCounted
## Rolls random items: slot, rarity, then distinct affixes allowed in that
## slot, with values growing with the zone level.

var _config: LootConfig
var _rng := RandomNumberGenerator.new()


func _init(config: LootConfig, seed_value: int = 0) -> void:
	_config = config
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func roll(zone_level: int) -> ItemData:
	var item := ItemData.new()
	item.slot = _rng.randi_range(0, 2)
	item.rarity = _pick_weighted(_config.rarity_weights)
	item.item_level = zone_level
	var growth := 1.0 + _config.value_growth_per_zone * (zone_level - 1)
	var allowed: Array[AffixDef] = []
	for affix in _config.affixes:
		if affix.slots.has(item.slot):
			allowed.append(affix)
	var wanted := mini(_config.rarity_affixes[item.rarity], allowed.size())
	for _n in wanted:
		var weights := PackedFloat32Array()
		for affix in allowed:
			weights.append(affix.weight)
		var picked := allowed[_pick_weighted(weights)]
		allowed.erase(picked)
		var value := _rng.randf_range(picked.min_value, picked.max_value) * growth
		item.stats.append(picked.stat)
		item.values.append(_round_value(picked.stat, value))
	item.item_name = _name_for(item)
	return item


func _name_for(item: ItemData) -> String:
	var base := _config.slot_names[item.slot]
	if item.rarity >= 2 and not _config.rare_prefixes.is_empty():
		return "%s %s" % [_config.rare_prefixes[_rng.randi() % _config.rare_prefixes.size()], base]
	if item.rarity == 1 and not item.stats.is_empty():
		return "%s of %s" % [base, PlayerStat.NAMES[item.stats[0]].capitalize()]
	return base


func _round_value(stat: int, value: float) -> float:
	if PlayerStat.IS_PERCENT[stat] != 0:
		return roundf(value * 100.0) / 100.0
	return roundf(value * 10.0) / 10.0


func _pick_weighted(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := _rng.randf() * total
	for k in weights.size():
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.size() - 1
